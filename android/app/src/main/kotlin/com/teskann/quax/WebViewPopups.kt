package com.teskann.quax

import android.app.Activity
import android.app.Dialog
import android.os.Message
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugins.webviewflutter.WebChromeClientProxyApi
import java.util.Collections
import java.util.WeakHashMap

/**
 * webview_flutter discards the WebView created for `window.open`, so the opened page has no `window.opener`. The
 * "Sign in with Google" button of X needs it to hand its token back, so the popup is shown here instead. The plugin
 * only accepts its own SecureWebChromeClient, hence the inheritance.
 */
object WebViewPopups {
    private val patched: MutableSet<WebView> = Collections.newSetFromMap(WeakHashMap())

    fun install(activity: Activity) {
        webViews(activity.window.decorView)
            .filter { patched.add(it) }
            .forEach { it.webChromeClient = PopupChromeClient(activity) }
    }

    private fun webViews(view: View): Sequence<WebView> = when (view) {
        is WebView -> sequenceOf(view)
        is ViewGroup -> (0 until view.childCount).asSequence().flatMap { webViews(view.getChildAt(it)) }
        else -> emptySequence()
    }

    private class PopupChromeClient(private val activity: Activity) :
        WebChromeClientProxyApi.SecureWebChromeClient() {
        override fun onCreateWindow(
            view: WebView,
            isDialog: Boolean,
            isUserGesture: Boolean,
            resultMsg: Message,
        ): Boolean {
            val popup = createPopup(view)
            val dialog = Dialog(activity, android.R.style.Theme_DeviceDefault_Light_NoActionBar).apply {
                setContentView(popup)
                setOnDismissListener { popup.destroy() }
            }
            popup.webChromeClient = object : WebChromeClient() {
                override fun onCloseWindow(window: WebView) = dialog.dismiss()
            }
            (resultMsg.obj as WebView.WebViewTransport).webView = popup
            resultMsg.sendToTarget()
            dialog.show()
            return true
        }

        private fun createPopup(opener: WebView): WebView = WebView(activity).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.javaScriptCanOpenWindowsAutomatically = true
            settings.userAgentString = opener.settings.userAgentString
            webViewClient = WebViewClient()
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        }
    }
}

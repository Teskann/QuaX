package com.teskann.quax

import android.webkit.WebView
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * Gives WebViews the user agent metadata (`sec-ch-ua*`) of Chrome. Otherwise they list themselves as "Android WebView"
 * whatever their user agent says. Older WebViews keep their own.
 *
 * A plugin, so that it gets the binding webview_flutter_android needs to find a WebView of Flutter.
 */
class WebViewUserAgentMetadata : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        this.binding = null
    }

    // Arguments sent by login_webview.dart
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "set") return result.notImplemented()
        // Integer or Long, depending on how big the id is
        val identifier = call.argument<Number>("webViewIdentifier")!!.toLong()
        val webView = binding?.let { WebViewFlutterAndroidExternalApi.getWebView(it, identifier) }
        result.success(
            webView != null && set(webView, call.argument("brands")!!, call.argument("fullVersion")!!)
        )
    }

    companion object {
        private const val CHANNEL = "webview_user_agent_metadata"

        fun copy(from: WebView, to: WebView) {
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)) return
            WebSettingsCompat.setUserAgentMetadata(to.settings, WebSettingsCompat.getUserAgentMetadata(from.settings))
        }

        /** Returns false when the WebView cannot take it. */
        private fun set(webView: WebView, brands: List<Map<String, String>>, fullVersion: String): Boolean {
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)) return false
            val metadata = UserAgentMetadata.Builder(WebSettingsCompat.getUserAgentMetadata(webView.settings))
                .setBrandVersionList(brands.map(::toBrandVersion))
                .setFullVersion(fullVersion)
                .build()
            WebSettingsCompat.setUserAgentMetadata(webView.settings, metadata)
            return true
        }

        private fun toBrandVersion(brand: Map<String, String>): UserAgentMetadata.BrandVersion =
            UserAgentMetadata.BrandVersion.Builder()
                .setBrand(brand.getValue("name"))
                .setMajorVersion(brand.getValue("majorVersion"))
                .setFullVersion(brand.getValue("fullVersion"))
                .build()
    }
}

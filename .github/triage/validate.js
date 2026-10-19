const TYPES = {
  object: (v) => typeof v === 'object' && v !== null && !Array.isArray(v),
  array: Array.isArray,
  string: (v) => typeof v === 'string',
  integer: Number.isInteger,
}

const ownErrors = (s, value, at) =>
  [
    s.const !== undefined && value !== s.const && `${at} must be ${JSON.stringify(s.const)}`,
    s.enum && !s.enum.includes(value) && `${at} must be one of ${s.enum.join(', ')}`,
    s.pattern && !new RegExp(s.pattern, 'u').test(value) && `${at} must match ${s.pattern}`,
    s.minItems !== undefined && value.length < s.minItems && `${at} needs ${s.minItems}+ items`,
    s.maxItems !== undefined && value.length > s.maxItems && `${at} allows ${s.maxItems} items`,
    s.uniqueItems && new Set(value).size !== value.length && `${at} has duplicates`,
    s.minProperties !== undefined &&
      Object.keys(value).length < s.minProperties &&
      `${at} needs ${s.minProperties}+ properties`,
    ...(s.required ?? [])
      .filter((k) => !Object.hasOwn(value, k))
      .map((k) => `${at}.${k} is missing`),
    ...(s.additionalProperties === false
      ? Object.keys(value)
          .filter((k) => !Object.hasOwn(s.properties ?? {}, k))
          .map((k) => `${at}.${k} is not allowed`)
      : []),
  ].filter(Boolean)

const childErrors = (s, value, at) => [
  ...Object.entries(s.properties ?? {})
    .filter(([k]) => Object.hasOwn(value, k))
    .flatMap(([k, sub]) => validate(sub, value[k], `${at}.${k}`)),
  ...(s.items ? value.flatMap((item, i) => validate(s.items, item, `${at}[${i}]`)) : []),
]

function validate(s, value, at = '$') {
  if (s.type && !TYPES[s.type]) throw new Error(`Unsupported schema type: ${s.type}`)
  if (s.type && !TYPES[s.type](value)) return [`${at} must be a ${s.type}`]
  return [...ownErrors(s, value, at), ...childErrors(s, value, at)]
}

module.exports = { validate }

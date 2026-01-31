import nextra from 'nextra'

const withNextra = nextra({
  search: {
    codeblocks: false
  }
})

export default withNextra({
  output: 'export',
  basePath: '/helm-charts',
  images: {
    unoptimized: true
  },
  i18n: {
    locales: ['en'],
    defaultLocale: 'en'
  },
  turbopack: {
    resolveAlias: {
      'next-mdx-import-source-file': './mdx-components.js'
    }
  }
})

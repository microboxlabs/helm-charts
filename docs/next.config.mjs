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
  turbopack: {
    resolveAlias: {
      'next-mdx-import-source-file': './mdx-components.js'
    }
  }
})

import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'
import '../globals.css'

export const metadata = {
  title: {
    default: 'MBL Helm Charts',
    template: '%s | MBL Helm Charts'
  },
  description: 'Documentation for MicroboxLabs Helm Charts distribution including Alfresco and custom charts.',
}

const navbar = (
  <Navbar
    logo={
      <span style={{ fontWeight: 700, fontSize: '1.1rem' }}>
        MBL Helm Charts
      </span>
    }
    projectLink="https://github.com/microboxlabs/helm-charts"
  />
)

const footer = (
  <Footer>
    <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', flexWrap: 'wrap', gap: '1rem' }}>
      <span>MIT {new Date().getFullYear()} © MicroboxLabs</span>
      <span>
        <a href="https://docs.modulariot.com" target="_blank" rel="noopener noreferrer">
          ModularIoT Docs
        </a>
      </span>
    </div>
  </Footer>
)

function prefixRoutes(items: any[], lang: string): any[] {
  return items.map(item => {
    if (!item.route) return item
    return {
      ...item,
      route: `/${lang}${item.route}`,
      ...(item.children && { children: prefixRoutes(item.children, lang) })
    }
  })
}

export default async function RootLayout({ children, params }: { children: React.ReactNode, params: Promise<{ lang: string }> }) {
  const { lang } = await params
  const pageMap = await getPageMap(`/${lang}`)

  return (
    <html
      lang={lang}
      dir="ltr"
      suppressHydrationWarning
    >
      <Head>
        <link rel="icon" href="/helm-charts/favicon.ico" />
      </Head>
      <body>
        <Layout
          navbar={navbar}
          pageMap={prefixRoutes(pageMap, lang)}
          docsRepositoryBase="https://github.com/microboxlabs/helm-charts/tree/trunk/docs"
          footer={footer}
          editLink="Edit this page on GitHub"
          feedback={{ content: null }}
          sidebar={{ defaultMenuCollapseLevel: 1 }}
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}

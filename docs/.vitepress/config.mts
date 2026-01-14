import { defineConfig } from 'vitepress';
import llmstxt from 'vitepress-plugin-llms';

// Site configuration
const SITE_URL = 'https://muhammad-fiaz.github.io/zigx';
const SITE_TITLE = 'ZIGX';
const SITE_DESCRIPTION = 'Fast, light-weight compressed file format specifically designed for Zig distribution packages';

// Google Analytics and Google Tag Manager IDs
export const GA_ID = 'G-6BVYCRK57P';
export const GTM_ID = 'GTM-P4M9T8ZR';

// Google AdSense Client ID
export const ADSENSE_CLIENT_ID = 'ca-pub-2040560600290490';

export default defineConfig({
  title: SITE_TITLE,
  description: SITE_DESCRIPTION,
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,
  base: '/zigx/',
  
  vite: {
    plugins: [llmstxt()]
  },
  
  head: [
    // Favicon - multiple formats for browser compatibility
    ['link', { rel: 'icon', type: 'image/x-icon', href: '/zigx/favicon.ico' }],
    ['link', { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/zigx/favicon-32x32.png' }],
    ['link', { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/zigx/favicon-16x16.png' }],
    ['link', { rel: 'apple-touch-icon', sizes: '180x180', href: '/zigx/apple-touch-icon.png' }],
    ['link', { rel: 'manifest', href: '/zigx/site.webmanifest' }],
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    
    // Open Graph / Facebook
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:url', content: SITE_URL }],
    ['meta', { property: 'og:title', content: SITE_TITLE }],
    ['meta', { property: 'og:description', content: SITE_DESCRIPTION }],
    ['meta', { property: 'og:image', content: `${SITE_URL}/zigx.png` }],
    ['meta', { property: 'og:site_name', content: SITE_TITLE }],
    ['meta', { property: 'og:locale', content: 'en_US' }],
    
    // Twitter
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:url', content: SITE_URL }],
    ['meta', { name: 'twitter:title', content: SITE_TITLE }],
    ['meta', { name: 'twitter:description', content: SITE_DESCRIPTION }],
    ['meta', { name: 'twitter:image', content: `${SITE_URL}/zigx.png` }],
    
    // SEO Meta Tags
    ['meta', { name: 'author', content: 'Muhammad Fiaz' }],
    ['meta', { name: 'keywords', content: 'zig, compression, zigx, zstd, zstandard, archive, bundler, high-performance' }],
    ['meta', { name: 'robots', content: 'index, follow' }],
    ['meta', { name: 'googlebot', content: 'index, follow' }],
    ['link', { rel: 'canonical', href: SITE_URL }],
    
    // Google Tag Manager
    ['script', {}, `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
      new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
      j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
      'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
    })(window,document,'script','dataLayer','${GTM_ID}');`],
    
    // Google Analytics
    ['script', { async: 'true', src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}` }],
    ['script', {}, `window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', '${GA_ID}');`],
    
    // Google AdSense
    ['script', { 
      async: 'true', 
      src: `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`,
      crossorigin: 'anonymous'
    }],
    
    // JSON-LD Schema - SoftwareApplication
    ['script', { type: 'application/ld+json' }, JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      'name': 'ZIGX',
      'applicationCategory': 'DeveloperApplication',
      'operatingSystem': 'Windows, macOS, Linux',
      'description': SITE_DESCRIPTION,
      'url': SITE_URL,
      'offers': {
        '@type': 'Offer',
        'price': '0',
        'priceCurrency': 'USD'
      },
      'softwareVersion': '0.0.1',
      'programmingLanguage': 'Zig',
      'license': 'https://opensource.org/licenses/Apache-2.0'
    })],
    
    // JSON-LD Schema - TechArticle
    ['script', { type: 'application/ld+json' }, JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'TechArticle',
      'headline': 'ZIGX Documentation',
      'description': 'Complete documentation for ZIGX compression library',
      'author': {
        '@type': 'Person',
        'name': 'Muhammad Fiaz'
      },
      'publisher': {
        '@type': 'Organization',
        'name': 'ZIGX',
        'url': SITE_URL
      }
    })]
  ],
  
  sitemap: {
    hostname: SITE_URL
  },
  
  themeConfig: {
    logo: '/zigx.png',
    siteTitle: 'ZIGX',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/' },
      { text: 'Examples', link: '/examples/' },
      {
        text: 'v0.0.1',
        items: [
          { text: 'Changelog', link: '/changelog' },
          { text: 'Contributing', link: '/contributing' }
        ]
      }
    ],
    
    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is ZIGX?', link: '/guide/' },
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' }
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Compression', link: '/guide/compression' },
            { text: 'Format Specification', link: '/guide/format' },
            { text: 'Versioning', link: '/guide/versioning' }
          ]
        },
        {
          text: 'Usage',
          items: [
            { text: 'Bundling', link: '/guide/bundling' },
            { text: 'Extracting', link: '/guide/extracting' },
            { text: 'Exclude Patterns', link: '/guide/exclude-patterns' },
            { text: 'Metadata', link: '/guide/metadata' },
            { text: 'Repair & Update', link: '/guide/repair-and-update' }
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Validation', link: '/guide/validation' },
            { text: 'Security', link: '/guide/security' },
            { text: 'Performance', link: '/guide/performance' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'bundle / compress', link: '/api/compress' },
            { text: 'unbundle / extract', link: '/api/extract' },
            { text: 'getArchiveInfo', link: '/api/get-archive-info' },
            { text: 'validate / verify', link: '/api/validate' },
            { text: 'manager', link: '/api/manager' },
            { text: 'Types', link: '/api/types' }
          ]
        }
      ],
      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            { text: 'Basic Usage', link: '/examples/basic' },
            { text: 'Self-Bundling', link: '/examples/self-bundle' },
            { text: 'Custom Metadata', link: '/examples/metadata' },
            { text: 'Exclude Patterns', link: '/examples/exclude' }
          ]
        }
      ]
    },
    
    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/zigx' }
    ],
    
    footer: {
      message: 'Released under the Apache License 2.0.',
      copyright: 'Copyright © Muhammad Fiaz'
    },
    
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    
    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/zigx/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },
    
    lastUpdated: {
      text: 'Last updated',
      formatOptions: {
        dateStyle: 'medium',
        timeStyle: 'short'
      }
    }
  }
});

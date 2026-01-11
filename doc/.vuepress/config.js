import { viteBundler } from '@vuepress/bundler-vite'
import { defaultTheme } from '@vuepress/theme-default'
import { defineUserConfig } from 'vuepress'

export default defineUserConfig({
	bundler: viteBundler(),
	title : 'Pico GPU',
	dest : 'docs',
	base : '/picogpu/',
	head : [
		['script',{src:"fflate.js"}],
		['script',{src:"picogpu.js"}]
	],
	theme: defaultTheme({
		colorMode: 'dark',
		lastUpdated: false,
		contributors: false,
		prevLink: false,
		nextLink: false,
		sidebar : [
		{
			text : 'Home',
			link : '/',
			children : []
		},
		{
			text : 'Start',
			link : '/Start.html'
		},
		'Doc.md',
		{
			text : 'Download',
			link : 'https://github.com/ncannasse/picogpu/releases'
		},
		'About.md'
	]
	})
})
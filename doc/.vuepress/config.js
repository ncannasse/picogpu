import { viteBundler } from '@vuepress/bundler-vite'
import { defaultTheme } from '@vuepress/theme-default'
import { defineUserConfig } from 'vuepress'

export default defineUserConfig({
	bundler: viteBundler(),
	title : 'Pico GPU',
	dest : 'www',
	head : [
		['script',{src:"fflate.js"}],
		['script',{src:"picogpu.js"}]
	],
	theme: defaultTheme({
	colorMode: 'dark',
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
		'About.md'
	]
	})
})
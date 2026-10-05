export default {
	content: ["./src/**/*.{ts,vue}"],
	theme: {
		extend: {
			fontFamily: {
				sans: [
					"Plus Jakarta Sans Variable",
					"Plus Jakarta Sans",
					"ui-sans-serif",
					"-apple-system",
					"system-ui",
					"Segoe UI",
					"Helvetica",
					"Apple Color Emoji",
					"Arial",
					"sans-serif",
					"Segoe UI Emoji",
					"Segoe UI Symbol",
				],
				mono: ["Mono-Font", "ui-monospace", "SFMono-Regular", "SF Mono", "Menlo", "Consolas", "Liberation Mono", "monospace"],
				display: ["Playfair Display", "ui-sans-serif", "serif"],
			},
		},
	},
	plugins: [],
};

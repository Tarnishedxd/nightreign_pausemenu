export default {
	plugins: {
		tailwindcss: {},
		autoprefixer: {},
		"@minko-fe/postcss-pxtorem": {
			rootValue: 16,
			propList: ["*"],
			selectorBlackList: ["shadow", "blur", "drop-shadow"],
			minPixelValue: 2,
		},
	},
};

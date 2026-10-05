import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import AutoImport from "unplugin-auto-import/vite";
import Components from "unplugin-vue-components/vite";
import { fileURLToPath, URL } from "node:url";
import { blipManifestPlugin } from "./plugins/blipManifest";

const webRoot = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
	plugins: [
		vue(),
		blipManifestPlugin(webRoot),

		AutoImport({
			imports: [
				"vue",
				"pinia",
				{
					"@vueuse/core": ["useStorage"],
				},
				{
					"@laot/nuix": [
						"fetchNui",
						"applyLtBatch",
						"replaceLtState",
						"isEnvBrowser",
						"onNuiMessage",
						"onNuiAction",
						"setNuiMocks",
						"clearNuiMocks",
					],
				},
			],
			dirs: ["./src/stores", "./src/composables", "./src/utils", "./src/types", "./src/assets"],
			dts: true,
			vueTemplate: true,
		}),

		Components({
			dts: true,
			dirs: ["./src/pages", "./src/components"],
			deep: true,
		}),
	],
	base: "./",
	resolve: {
		alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
	},
	build: {
		outDir: "build",
		emptyOutDir: true,
	},
});

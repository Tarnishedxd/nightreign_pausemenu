/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-05-21
 */

export const useLocaleStore = defineStore("locale", {
	state: (): LocaleStore => ({
		locale: "en",
		translations: {},
	}),
	actions: {
		updateLocale(locale: string) {
			this.locale = locale;
		},
		updateTranslations(data: LocaleStore["translations"]) {
			this.translations = data;
		},
	},
});

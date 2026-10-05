/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-05-07
 */

/**
 * Retrieves a localized string from the global store and formats it like LUA.
 *
 * @param key - The locale key to look up in the store.
 * @param fallback - Optional fallback string if the key is not found. Defaults to the key itself.
 * @param args - Variable arguments that replace format conversion specifiers in the localized string.
 *
 * Supported Format Specifiers:
 * - `%d`: Integer
 * - `%f`: Float
 * - `%s`: String
 * - `%%`: Literal `%` character
 *
 * @returns The formatted localized string, or the fallback value if the key is missing.
 */
export const _t = (key: string, fallback?: string, ...args: any[]): string => {
	const store = useLocaleStore();
	let text: string;

	if (!store.translations || Object.keys(store.translations).length === 0) {
		text = fallback || key;
	} else {
		if (store.translations[key] !== undefined) {
			text = String(store.translations[key]);
		} else {
			text = fallback || key;
		}
	}

	if (args.length > 0) {
		let i = 0;
		text = text.replace(/%([dfsxXeE%])/g, (match, specifier) => {
			if (specifier === "%") return "%";

			if (i >= args.length) return match;
			const val = args[i++];

			switch (specifier) {
				case "d":
					return String(parseInt(String(val), 10));
				case "f":
					return String(Number(val));
				case "s":
					return String(val);
				default:
					return match;
			}
		});
	}

	return text;
};

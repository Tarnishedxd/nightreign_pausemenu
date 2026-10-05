/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-06-05
 */

/**
 * Get the asset URL from the given path.
 * @param path - The path to the asset. Example: "assets/images/logo.png"
 * @returns The asset URL.
 */
export function assetURL(path: string): string {
	const clean = path.replace(/^\//, "");
	return `${import.meta.env.BASE_URL}${clean}`;
}

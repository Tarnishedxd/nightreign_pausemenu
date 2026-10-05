/// <reference types="vite/client" />

declare module "virtual:blip-manifest" {
	export const blipMetas: { id: number | null; name: string; file: string }[];
}

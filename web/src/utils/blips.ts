import { blipMetas as scannedBlipMetas } from "virtual:blip-manifest";
import { assetURL } from "@/utils/assetURL";

export type BlipMeta = {
	id: number | null;
	name: string;
	file: string;
};

export const blipMetas: BlipMeta[] = scannedBlipMetas;

const byName = new Map<string, BlipMeta>();
const byId = new Map<number, BlipMeta>();

for (const meta of blipMetas) {
	byName.set(meta.name.toLowerCase(), meta);
	if (meta.id !== null) byId.set(meta.id, meta);
}

function resolveMeta(sprite: string): BlipMeta | undefined {
	const raw = sprite.replace(/\.png$/i, "").trim();
	if (!raw) return undefined;

	const asId = Number(raw);
	if (Number.isInteger(asId) && String(asId) === raw) {
		return byId.get(asId);
	}

	const lower = raw.toLowerCase();
	const named = byName.get(lower);
	if (named) return named;

	const prefixed = lower.match(/^(\d+)-(radar_.+)$/);
	if (prefixed?.[1] && prefixed[2]) {
		const byPrefixedName = byName.get(prefixed[2]);
		if (byPrefixedName) return byPrefixedName;
		const byPrefixedId = byId.get(Number(prefixed[1]));
		if (byPrefixedId) return byPrefixedId;
	}

	return undefined;
}

export function blipSrc(sprite: string): string {
	const meta = resolveMeta(sprite);
	if (meta) return assetURL(`images/blips/${meta.file}.png`);

	const name = sprite.replace(/\.png$/i, "").trim();
	if (!name) return "";
	return assetURL(`images/blips/${name}.png`);
}

export function blipSpriteId(sprite: string): number {
	return resolveMeta(sprite)?.id ?? 1;
}

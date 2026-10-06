import fs from "node:fs";
import path from "node:path";
import type { Plugin } from "vite";

export type BlipMeta = {
	id: number | null;
	name: string;
	file: string;
};

const VIRTUAL_ID = "virtual:blip-manifest";
const RESOLVED_ID = "\0" + VIRTUAL_ID;
const ID_PREFIXED = /^(\d+)-(radar_.+)\.png$/i;
const BARE_RADAR = /^(radar_.+)\.png$/i;

function scanBlipsDir(dir: string): BlipMeta[] {
	if (!fs.existsSync(dir)) return [];
	return fs
		.readdirSync(dir)
		.map((fileName) => {
			const idMatch = fileName.match(ID_PREFIXED);
			if (idMatch) {
				return {
					id: Number(idMatch[1]),
					name: idMatch[2].toLowerCase(),
					file: fileName.replace(/\.png$/i, ""),
				};
			}
			const bare = fileName.match(BARE_RADAR);
			if (bare) {
				return {
					id: null,
					name: bare[1].toLowerCase(),
					file: fileName.replace(/\.png$/i, ""),
				};
			}
			return null;
		})
		.filter((meta): meta is BlipMeta => meta !== null)
		.sort((a, b) => {
			if (a.id !== null && b.id !== null) return a.id - b.id;
			if (a.id !== null) return -1;
			if (b.id !== null) return 1;
			return a.name.localeCompare(b.name);
		});
}

// The file name already holds the id and the name ("1-radar_level"), so ship only the file
// names and rebuild the entries at startup: about a third of the size of the full JSON.
function moduleSource(metas: BlipMeta[]): string {
	const files = metas.map((meta) => meta.file).join(",");
	return `const files = ${JSON.stringify(files)};
export const blipMetas = files ? files.split(",").map((file) => {
	const match = /^(\\d+)-(radar_.+)$/i.exec(file);
	return match
		? { id: Number(match[1]), name: match[2].toLowerCase(), file }
		: { id: null, name: file.toLowerCase(), file };
}) : [];`;
}

export function blipManifestPlugin(root: string): Plugin {
	const blipsDir = path.join(root, "public", "images", "blips");
	let metas: BlipMeta[] = [];

	const refresh = () => {
		metas = scanBlipsDir(blipsDir);
	};

	return {
		name: "blip-manifest",
		buildStart() {
			refresh();
		},
		resolveId(id) {
			if (id === VIRTUAL_ID) return RESOLVED_ID;
		},
		load(id) {
			if (id === RESOLVED_ID) return moduleSource(metas);
		},
		// The game side reads this too: blip sprite id -> icon name, to put the GTA map legend's
		// names (which carry the icon name, not the id) on the blips it finds.
		generateBundle() {
			const names: Record<string, string> = {};
			for (const meta of metas) if (meta.id !== null) names[String(meta.id)] = meta.name;
			this.emitFile({ type: "asset", fileName: "blips.json", source: JSON.stringify(names) });
		},
		configureServer(server) {
			refresh();
			if (!fs.existsSync(blipsDir)) return;
			server.watcher.add(blipsDir);
			const onChange = (file: string) => {
				if (!file.startsWith(blipsDir)) return;
				refresh();
				const mod = server.moduleGraph.getModuleById(RESOLVED_ID);
				if (mod) server.moduleGraph.invalidateModule(mod);
				server.ws.send({ type: "full-reload" });
			};
			server.watcher.on("add", onChange);
			server.watcher.on("unlink", onChange);
		},
	};
}

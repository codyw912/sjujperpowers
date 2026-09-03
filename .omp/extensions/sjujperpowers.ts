import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const skillsDir = resolve(extensionDir, "../../skills");

export default function sjujperpowersOmpExtension(omp: ExtensionAPI) {
	omp.on("resources_discover", async () => ({
		skillPaths: [skillsDir],
	}));
}

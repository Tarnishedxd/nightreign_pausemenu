/**
 * @author laot
 * @github https://github.com/laot7490
 * @created 2026-06-16
 */

import { createApp } from "vue";
import { createPinia } from "pinia";

// Import style (font is bundled: an external stylesheet would block the UI from starting when it cannot load)
import "@/assets/fonts.css";
import "@/assets/index.css";

// Import app
import App from "@/index.vue";

// Create app
const app = createApp(App);

// Use pinia
app.use(createPinia());

// Import FiveM API
import "@/services/api";

// Mount app
app.mount("#app");

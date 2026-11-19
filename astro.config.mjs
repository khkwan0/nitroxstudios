// @ts-check
import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

// https://astro.build/config
export default defineConfig({
  site: "https://nitroxstudios.com",
  integrations: [
    sitemap({
      filter: (page) => !page.includes("/404"),
      customPages: [
        "https://nitroxstudios.com/aula/",
        "https://nitroxstudios.com/meme/",
      ],
      changefreq: "weekly",
      priority: 0.7,
      serialize(item) {
        if (item.url === "https://nitroxstudios.com/") {
          item.priority = 1.0;
          item.changefreq = "weekly";
        }
        if (item.url === "https://nitroxstudios.com/aula/") {
          item.priority = 0.8;
          item.changefreq = "monthly";
        }
        if (item.url === "https://nitroxstudios.com/meme/") {
          item.priority = 0.8;
          item.changefreq = "monthly";
        }
        if (item.url.replace(/\/$/, "") === "https://nitroxstudios.com/software") {
          item.priority = 0.4;
          item.changefreq = "monthly";
        }
        return item;
      },
    }),
  ],
});

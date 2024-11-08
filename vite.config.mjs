import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import StimulusHMR from "vite-plugin-stimulus-hmr";
import FullReload from "vite-plugin-full-reload";

export default defineConfig({
  plugins: [
    RubyPlugin(),
    StimulusHMR(),
    FullReload(
      [
        "config/routes.rb",
        "app/views/**/*.erb",
        "./app/views/**/*.rb"
      ],
      { delay: 200 }
    )
  ],
  css: {
    postcss: './postcss.config.cjs',
  },
  build: {
    manifest: true,
    outDir: 'public/assets',
    rollupOptions: {
      input: {
        application: './app/javascript/application.js'
      }
    }
  }
});

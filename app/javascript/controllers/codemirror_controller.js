import { Controller } from "@hotwired/stimulus"
import CodeMirror from "codemirror"
import "codemirror/mode/ruby/ruby"
import "codemirror/mode/yaml/yaml"
import "codemirror/lib/codemirror.css"
import "codemirror/theme/monokai.css"

export default class extends Controller {
  static values = {
    mode: String,
    readonly: { type: Boolean, default: false }
  }

  connect() {
    const config = {
      mode: this.modeValue || "ruby",
      theme: "monokai",
      lineNumbers: true,
      lineWrapping: true,
      readOnly: this.readonlyValue,
      tabSize: 2,
      indentWithTabs: false,
      viewportMargin: Infinity,
      scrollbarStyle: null,
      fixedGutter: true,
      gutters: ["CodeMirror-linenumbers"]
    }

    if (!this.readonlyValue) {
      config.autofocus = true
      config.extraKeys = {
        "Tab": (cm) => {
          if (cm.somethingSelected()) {
            cm.indentSelection("add")
          } else {
            cm.replaceSelection("  ", "end")
          }
        }
      }
    }

    // For read-only mode, we need to create a new div and set its content
    if (this.readonlyValue) {
      const content = this.element.textContent.trim()
      this.element.textContent = ""
      this.editor = CodeMirror(this.element, {
        ...config,
        value: content
      })
    } else {
      this.editor = CodeMirror.fromTextArea(this.element, config)
    }

    if (!this.readonlyValue) {
      this.editor.on("change", () => {
        this.element.value = this.editor.getValue()
        this.element.dispatchEvent(new Event("input"))
      })
    }

    // Refresh after initialization to ensure proper rendering
    setTimeout(() => this.editor.refresh(), 1)
  }

  disconnect() {
    if (this.editor) {
      if (!this.readonlyValue) {
        this.editor.toTextArea()
      }
      this.editor = null
    }
  }
}

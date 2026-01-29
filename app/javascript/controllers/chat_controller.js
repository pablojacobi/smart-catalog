import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "welcome"]
  static values = { conversationId: String }

  connect() {
    this.isStreaming = false
    this.inputTarget.focus()
  }

  send(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message || this.isStreaming) return

    this.addUserMessage(message)
    this.inputTarget.value = ""
    this.startStreaming()

    // Hide welcome message on first interaction
    if (this.hasWelcomeTarget) {
      this.welcomeTarget.classList.add("hidden")
    }

    this.streamResponse(message)
  }

  quickQuestion(event) {
    const question = event.target.textContent.replace(/^"|"$/g, "")
    this.inputTarget.value = question
    this.send(event)
  }

  addUserMessage(content) {
    const html = `
      <div class="flex gap-4 justify-end">
        <div class="flex-1 max-w-[80%]">
          <div class="bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-2xl rounded-tr-none px-4 py-3 ml-auto">
            <p>${this.escapeHtml(content)}</p>
          </div>
        </div>
        <div class="flex-shrink-0 w-8 h-8 bg-gray-300 rounded-lg flex items-center justify-center">
          <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
          </svg>
        </div>
      </div>
    `
    this.appendMessage(html)
  }

  addAssistantMessage() {
    const id = `assistant-${Date.now()}`
    const html = `
      <div class="flex gap-4" id="${id}">
        <div class="flex-shrink-0 w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
          <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
          </svg>
        </div>
        <div class="flex-1">
          <div class="bg-white rounded-2xl rounded-tl-none px-4 py-3 shadow-sm border border-gray-100">
            <div class="prose prose-sm max-w-none text-gray-700" data-content></div>
            <div class="typing-indicator mt-2">
              <span class="inline-flex gap-1">
                <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0ms"></span>
                <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 150ms"></span>
                <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 300ms"></span>
              </span>
            </div>
          </div>
        </div>
      </div>
    `
    this.appendMessage(html)
    return document.getElementById(id)
  }

  appendMessage(html) {
    const container = this.messagesTarget.querySelector(".space-y-6")
    container.insertAdjacentHTML("beforeend", html)
    this.scrollToBottom()
  }

  startStreaming() {
    this.isStreaming = true
    this.sendButtonTarget.disabled = true
    this.inputTarget.disabled = true
  }

  stopStreaming() {
    this.isStreaming = false
    this.sendButtonTarget.disabled = false
    this.inputTarget.disabled = false
    this.inputTarget.focus()
  }

  async streamResponse(message) {
    const messageElement = this.addAssistantMessage()
    const contentElement = messageElement.querySelector("[data-content]")
    const typingIndicator = messageElement.querySelector(".typing-indicator")

    let fullContent = ""

    try {
      const params = new URLSearchParams({
        message: message,
        conversation_id: this.conversationIdValue
      })

      const eventSource = new EventSource(`/chat/stream?${params}`)

      eventSource.addEventListener("chunk", (event) => {
        if (typingIndicator) {
          typingIndicator.remove()
        }
        // Decode escaped newlines from SSE
        const chunk = event.data.replace(/\\n/g, '\n').replace(/\\r/g, '\r')
        fullContent += chunk
        contentElement.innerHTML = this.renderMarkdown(fullContent)
        this.scrollToBottom()
      })

      eventSource.addEventListener("done", (event) => {
        const data = JSON.parse(event.data)
        this.conversationIdValue = data.conversation_id
        eventSource.close()
        this.stopStreaming()
      })

      eventSource.addEventListener("error", (event) => {
        if (typingIndicator) {
          typingIndicator.remove()
        }
        contentElement.innerHTML = `<p class="text-red-500">Sorry, an error occurred. Please try again.</p>`
        eventSource.close()
        this.stopStreaming()
      })

      eventSource.onerror = () => {
        eventSource.close()
        this.stopStreaming()
      }

    } catch (error) {
      console.error("Stream error:", error)
      contentElement.innerHTML = `<p class="text-red-500">Connection error. Please try again.</p>`
      this.stopStreaming()
    }
  }

  renderMarkdown(text) {
    // Simple markdown rendering
    return text
      // Headers
      .replace(/^### (.*$)/gim, '<h3 class="text-lg font-semibold mt-4 mb-2">$1</h3>')
      .replace(/^## (.*$)/gim, '<h2 class="text-xl font-bold mt-4 mb-2">$1</h2>')
      .replace(/^# (.*$)/gim, '<h1 class="text-2xl font-bold mt-4 mb-2">$1</h1>')
      // Bold
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      // Italic
      .replace(/\*(.*?)\*/g, '<em>$1</em>')
      // Code
      .replace(/`(.*?)`/g, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm">$1</code>')
      // Lists
      .replace(/^\- (.*$)/gim, '<li class="ml-4">$1</li>')
      .replace(/(<li.*<\/li>)\n/g, '<ul class="list-disc my-2">$1</ul>')
      // Line breaks
      .replace(/\n/g, '<br>')
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

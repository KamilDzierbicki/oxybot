# Shows an assistant answer in the browser while the model writes it. The streamed text is plain and unchecked; the
# finished reply replaces it with rendered markdown whose citations were checked (Conversation::Turn), so nothing
# unchecked stays on the page. Updates are sent at most every INTERVAL seconds, and the streaming body is
# aria-busy, so a screen reader announces the finished answer once instead of every update.
class Conversation::Stream
  INTERVAL = 0.25

  def initialize(reply)
    @reply = reply
    @text = +""
    @sent_at = nil
  end

  def to_proc = method(:<<).to_proc

  def <<(chunk)
    return if chunk.content.blank?

    @text << chunk.content
    broadcast if due?
  end

  # Text before a tool call is the model thinking aloud; the answer starts after the tools
  def restart
    @text = +""
  end

  private

  def due? = @sent_at.nil? || now - @sent_at >= INTERVAL
  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def broadcast
    @sent_at = now
    target = ActionView::RecordIdentifier.dom_id(@reply, :body)
    html = ApplicationController.helpers.tag.div(@text, id: target, class: "message__body message__streaming", aria: { busy: true })
    Turbo::StreamsChannel.broadcast_replace_to(@reply.conversation, target: target, html: html)
  end
end

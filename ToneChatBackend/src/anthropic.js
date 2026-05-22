/**
 * Shared Anthropic API helpers for chat and high-fidelity stylize.
 */

export async function completeAnthropic({
  apiKey,
  model,
  system,
  messages,
  maxTokens,
  temperature,
}) {
  const apiMessages = normalizeMessages(messages);
  if (apiMessages.length === 0) {
    throw new Error('No messages to send');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90_000);

  let res;
  try {
    res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        temperature,
        stream: false,
        system,
        messages: apiMessages,
      }),
    });
  } catch (e) {
    clearTimeout(timeout);
    throw new Error(e.name === 'AbortError' ? 'Anthropic request timed out' : e.message);
  }
  clearTimeout(timeout);

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(errText || `Anthropic error ${res.status}`);
  }

  const data = await res.json();
  const block = data.content?.find((b) => b.type === 'text');
  return {
    text: block?.text?.trim() ?? '',
    usage: data.usage ?? null,
  };
}

export async function streamAnthropicToSSE({
  apiKey,
  model,
  system,
  messages,
  maxTokens,
  temperature,
  sendSSE,
  finish,
}) {
  const apiMessages = normalizeMessages(messages);
  if (apiMessages.length === 0) {
    finish({ type: 'error', message: 'No messages to send' });
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 90_000);

  let upstream;
  try {
    upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        temperature,
        stream: true,
        system,
        messages: apiMessages,
      }),
    });
  } catch (e) {
    clearTimeout(timeout);
    const msg = e.name === 'AbortError' ? 'Anthropic request timed out' : e.message;
    finish({ type: 'error', message: msg });
    return;
  }
  clearTimeout(timeout);

  if (!upstream.ok) {
    const errText = await upstream.text();
    finish({ type: 'error', message: errText });
    return;
  }

  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let usage = { input_tokens: 0, output_tokens: 0 };

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';

      for (const line of lines) {
        if (!line.startsWith('data:')) continue;
        const data = line.slice(5).trim();
        if (!data || data === '[DONE]') continue;
        try {
          const event = JSON.parse(data);
          usage = mergeStreamUsage(usage, event);
          if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
            sendSSE({ type: 'delta', text: event.delta.text ?? '' });
          }
        } catch {
          /* ignore partial JSON */
        }
      }
    }
  } catch (e) {
    finish({ type: 'error', message: e.message ?? 'Stream failed' });
    return;
  }

  const hasUsage = usage.input_tokens > 0 || usage.output_tokens > 0;
  finish(hasUsage ? { usage } : {});
}

function mergeStreamUsage(current, event) {
  const next = { ...current };
  const u = event.message?.usage ?? event.usage;
  if (!u) return next;

  if (event.type === 'message_start' && u.input_tokens != null) {
    next.input_tokens = Math.max(next.input_tokens, u.input_tokens);
  }
  if (event.type === 'message_delta' && u.output_tokens != null) {
    next.output_tokens = Math.max(next.output_tokens, u.output_tokens);
  }
  if (u.input_tokens != null && event.type !== 'message_delta') {
    next.input_tokens = Math.max(next.input_tokens, u.input_tokens);
  }
  if (u.output_tokens != null) {
    next.output_tokens = Math.max(next.output_tokens, u.output_tokens);
  }
  return next;
}

function normalizeMessages(messages) {
  return messages
    .filter((m) => m.content?.trim())
    .map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content,
    }));
}

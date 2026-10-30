const form = document.querySelector('#feedback');
const status = document.querySelector('#status');
const file = document.querySelector('#diagnostics');
const preview = document.querySelector('#report');
let report = null;
let pending = null;
file?.addEventListener('change', async () => {
  report = null;
  preview.textContent = '';
  try {
    const selected = file.files[0];
    if (!selected) return;
    if (selected.size > 80 * 1024) throw new Error('诊断文件不能超过 80 KB。');
    const data = JSON.parse(await selected.text());
    if (data.schemaVersion !== 1 || !Array.isArray(data.events)) throw new Error('请选择电亮导出的诊断 JSON 文件。');
    report = data;
    preview.textContent = JSON.stringify(data, null, 2);
    status.textContent = '已在本机读取附件；点击提交前不会上传。';
    status.className = 'status';
  } catch (error) { file.value = ''; status.textContent = error.message; status.className = 'status error'; }
});
form?.addEventListener('submit', async event => {
  event.preventDefault();
  const button = form.querySelector('button[type=submit]');
  const payload = {message: form.message.value.trim(), email: form.email.value.trim(), consent: form.consent.checked, diagnostics: report, website: form.website.value};
  const content = JSON.stringify(payload);
  if (!pending || pending.content !== content) pending = { content, id: crypto.randomUUID() };
  button.disabled = true;
  status.textContent = '正在发送…';
  status.className = 'status';
  try {
    const response = await fetch('/api/feedback', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({...payload, id:pending.id}), signal: AbortSignal.timeout(20000) });
    if (!response.ok) throw new Error(response.status === 429 ? '提交较频繁，请一分钟后重试。' : `提交失败（${response.status}），请检查内容或稍后重试。`);
    const receipt = await response.json();
    if (receipt.id !== pending.id) throw new Error('未收到有效回执，请保留内容后重试。');
    status.textContent = `反馈已收到。请保存编号：${receipt.id}\n该编号可用于删除反馈，请勿公开。`;
    document.querySelector('#delete-id').value = receipt.id;
    form.reset(); report = null; pending = null; preview.textContent = '';
  } catch (error) { status.className = 'status error'; status.textContent = `${error.message}\n内容已保留，可重试。网络中断时暂无法确认是否收到。`; }
  finally { button.disabled = false; }
});
document.querySelector('#delete-form')?.addEventListener('submit', async event => {
  event.preventDefault();
  const output = document.querySelector('#delete-status');
  if (!confirm('删除该编号对应的在线反馈？此操作无法撤回。')) return;
  const button = event.target.querySelector('button'); button.disabled = true;
  try {
    const response = await fetch('/api/feedback/delete', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({id:document.querySelector('#delete-id').value.trim()}), signal:AbortSignal.timeout(20000)});
    if (!response.ok) throw new Error('暂时无法删除，请检查编号并稍后重试。');
    output.textContent = '删除请求已完成；该编号对应的在线记录已删除或原本不存在。';
  } catch (error) { output.textContent = error.message; }
  finally { button.disabled = false; }
});

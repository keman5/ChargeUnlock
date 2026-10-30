#!/usr/bin/env python3
"""Build the dependency-free public site; legal text shares the app's source."""
import html
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / 'site.json').read_text())
OUT = ROOT / 'dist'
if OUT.exists():
    shutil.rmtree(OUT)
shutil.copytree(ROOT / 'public', OUT)
shutil.copyfile(ROOT.parent / 'iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png', OUT / 'icon.png')
escape = html.escape
email = escape(CONFIG['supportEmail'])
nav = '<header><nav class="wrap"><a class="brand" href="/"><img src="/icon.png" alt="" width="42" height="42">电亮 <span class="small">PlugLit</span></a><a class="nav-link" href="/guide/">使用指南</a><a class="nav-link" href="/feedback/">问题反馈</a><a class="nav-link" href="/updates/">获取应用</a></nav></header>'
footer = f'<footer class="wrap"><div class="links"><a href="/privacy/">隐私政策</a><a href="/terms/">使用条款</a><a href="mailto:{email}">联系开发者</a><a href="/apps/">更多应用</a></div><p>本应用由吴凯开发并运营 · © 2026 PlugLit</p></footer>'

def page(path, title, body, script=False):
    target = OUT / path / 'index.html'
    target.parent.mkdir(parents=True, exist_ok=True)
    url = CONFIG['origin'] + '/' + (path + '/' if path else '')
    content = f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{escape(title)} · 电亮 PlugLit</title><meta name="description" content="电亮 PlugLit：连接电源，通过画中画显示充电画面；停止后沿用系统自动锁屏设置。使用指南、问题反馈与隐私说明。"><meta name="theme-color" content="#fffaf4"><link rel="canonical" href="{url}"><link rel="icon" href="/icon.png"><link rel="stylesheet" href="/style.css"></head><body>{nav}<main class="wrap">{body}</main>{footer}{'<script src="/feedback.js" defer></script>' if script else ''}</body></html>'''
    target.write_text(content)

page('', '插上电，让屏幕亮着', '''
<section class="hero"><div><div class="eyebrow">A little light for your workflow</div><h1>插上电，<br>让屏幕亮着。</h1><p class="lead">调试应用、查看信息，不必一次次唤醒屏幕。电亮用一扇小小的画中画显示充电画面，拔电后停止播放，沿用你原来的锁屏设置。</p><div class="actions"><a class="button" href="/updates/">查看发布进度 ↗</a><a class="button secondary" href="/guide/">了解怎么使用</a></div><p class="note">适用于 iPhone · iOS 17 及以上 · 尚未在 App Store 上架</p></div><div class="hero-art"><img src="/icon.png" alt="电亮的橙色闪电开锁图标" width="400" height="400"><span class="tag"><span class="dot"></span>有电，就有一点光</span></div></section>
<div class="strip"><span>不改动系统自动锁定时长</span><span>无需账号 · 无广告</span><span>内置画面，无需联网播放</span></div>
<section class="section split"><div><div class="eyebrow">Small window. Less interruption.</div><h2>把重复的操作，<br>留给充电自动化。</h2><p class="small">自动化需要你在系统快捷指令中设置。电亮不会代替你修改系统设置，也不会绕过锁屏密码。</p></div><div class="steps"><div class="step"><h3>连接电源，点亮画面</h3><p>打开电亮，点击“开启充电亮屏”。画中画启动后，可自行上滑返回桌面或切换应用。</p></div><div class="step"><h3>专注眼前的事情</h3><p>充电画面显示系统电量读数。窗口可以手动缩小或移到角落，尺寸与位置由 iOS 管理。</p></div><div class="step"><h3>拔掉电源，结束播放</h3><p>电亮停止本次会话。之后由系统按原来的设置决定锁屏时间；“永不”设置不会被改写。</p></div></div></section>
<section class="section split"><div><div class="eyebrow">Good to know</div><h2>一些值得先知道的事。</h2></div><div><details><summary>它能在所有情况下保持亮屏吗？</summary><p>不能保证。效果受 iOS、其他媒体、温度和电源状态影响。收起、暂停或关闭画中画可能结束亮屏；请在自己的设备上确认。持续亮屏会增加耗电和发热。</p></details><details><summary>连接电源就会自动启动吗？</summary><p>需先配置两条个人自动化：充电器连接时运行开启动作，断开时运行停止动作。锁屏插电可能需要先解锁。</p></details><details><summary>会上传我的设备数据吗？</summary><p>播放和日志默认在本机处理。只有你主动提交反馈并同意，才发送问题描述和选填的邮箱；诊断附件还需要单独选择。</p></details><details><summary>出现问题如何反馈？</summary><p>在应用“关于电亮 → 问题反馈与诊断”中预览、导出日志并提交，或在官网上传导出的报告。<a href="/feedback/">前往反馈</a>。</p></details></div></section>
''')

page('guide', '使用指南', '''<article class="document"><div class="eyebrow">Getting started</div><h1>从第一次点亮开始。</h1><h2>1. 手动使用</h2><p>连接电源，打开电亮，点击“开启充电亮屏”。画中画出现后，上滑返回桌面或切换到其他 App。需要结束时，返回电亮点“停止充电亮屏”，或关闭画中画。</p><h2>2. 配置充电自动化</h2><p>在系统“快捷指令 → 自动化”中新增“充电器 → 已连接”，选择立即运行，添加电亮的“开启充电亮屏”动作。再新增“充电器 → 已断开连接”，添加“停止充电亮屏”动作。系统版本不同，选项名称可能略有差异。</p><h2>3. 验证一次完整流程</h2><p>解锁手机，插电，确认充电画面出现；切到另一个 App 后拔电，确认画中画关闭，并等待原设置的自动锁定时间。若系统设置为“永不”，停止播放也不会强制锁屏。</p><h2>停用、卸载</h2><p>停止本次播放不会删除自动化。请在系统快捷指令中分别停用或删除两条充电器自动化，再删除应用，避免遗留规则反复报错。</p><h2>问题排查</h2><p>锁屏插电可能需要先解锁。其他媒体、视频通话或系统资源限制可能中断画中画。窗口不能通过 App 自动贴边隐藏。电量来自系统公开 API，与状态栏可能存在更新延迟。</p><p class="notice">不要将电亮用于必须持续显示的关键任务。持续亮屏、视频播放与充电会增加发热；设备过热时请停止使用。</p><a class="button" href="/feedback/">提交问题反馈</a></article>''')

page('updates', '获取应用与更新', f'''<article class="document"><div class="eyebrow">Release channel</div><h1>通过 Apple 获取更新。</h1><p class="notice">{escape(CONFIG['releaseStatus'])}</p><h2>正式版本</h2><p>App Store 产品页建立并公开后，这里会提供准确的下载链接。应用内更新入口将优先打开该产品页。目前不提供虚构的下载按钮，也不要求安装企业证书或描述文件。</p><h2>测试版本</h2><p>如开放测试，将使用 Apple TestFlight。当前没有公开邀请链接。</p><h2>已安装开发版本？</h2><p>请通过原开发安装渠道获取版本。iOS 版不使用 Sparkle，不会自行下载、执行或安装更新代码。</p><a href="mailto:{email}">联系开发者了解发布进度</a></article>''')

page('apps', '更多应用', '''<article class="document"><div class="eyebrow">Made with care</div><h1>先把这一点光做好。</h1><p>这里目前提供电亮 PlugLit 的产品介绍、使用指南和反馈支持。其他应用的官方发布入口确认后再添加。</p><a class="button" href="/">了解电亮</a></article>''')

page('feedback', '问题反馈', f'''<article class="document"><div class="eyebrow">We are listening</div><h1>告诉我们，哪里不太对。</h1><p>描述你想完成什么、实际发生了什么，以及如何重现。支持邮箱：<a href="mailto:{email}">{email}</a>。</p><p class="notice">在电亮中打开“关于电亮 → 问题反馈与诊断 → 预览与导出诊断报告”，保存 JSON 文件后可在此附上。网站无法可靠读取 iPhone 机型；应用导出的报告会自动包含机型标识和系统版本。</p>
<form id="feedback"><label class="field" for="message">问题描述 *</label><textarea id="message" name="message" minlength="10" maxlength="4000" required placeholder="例如：插电并开启画中画后，切换到…"></textarea><label class="field" for="email">联系邮箱（选填）</label><input id="email" name="email" type="email" maxlength="254" autocomplete="email" placeholder="用于回复这次反馈"><label class="field" for="diagnostics">诊断报告（选填，JSON，最多 80 KB）</label><input id="diagnostics" type="file" accept=".json,application/json"><p class="small">不上传也能反馈。文件只在本机预览，提交后才上传。请勿附上密码或无关个人资料。</p><details><summary>预览所选诊断内容</summary><pre id="report"></pre></details><div class="honeypot" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div><label class="check"><input name="consent" type="checkbox" required><span>我已阅读<a href="/privacy/">隐私政策</a>，同意将本次描述、选填邮箱与选取的诊断报告发送给吴凯用于排查和回复。服务由 Cloudflare 提供，服务器可能位于境外；在线反馈保留 30 天，到期后在下一次每小时清理任务中删除，可凭反馈编号删除。</span></label><button type="submit">提交反馈 ↗</button><div id="status" class="status" role="status" aria-live="polite"></div></form>
<h2>删除已提交的反馈</h2><p class="small">反馈编号是删除凭据，请勿公开。托管服务的灾备副本可能在其保留周期内继续存在。其他隐私请求请联系支持邮箱。</p><form id="delete-form"><label class="field" for="delete-id">反馈编号</label><input id="delete-id" required pattern="[0-9a-f]{{8}}-[0-9a-f]{{4}}-4[0-9a-f]{{3}}-[89ab][0-9a-f]{{3}}-[0-9a-f]{{12}}" autocomplete="off"><p><button type="submit">删除在线反馈</button></p><div id="delete-status" role="status" aria-live="polite"></div></form></article>''', True)

source = (ROOT.parent / 'iOS/AppInformation.swift').read_text()
for key, title in [('privacy', '隐私政策'), ('terms', '使用条款')]:
    text = re.search(r'static let '+key+r' = """\n(.*?)\n    """', source, re.S).group(1)
    parts = [x.strip() for x in text.split('\n\n')]
    body = '<article class="document"><h1>'+title+'</h1>'
    for part in parts:
        lines = [x.strip() for x in part.splitlines()]
        body += ('<h2>'+escape(lines[0])+'</h2><p>'+escape('\n'.join(lines[1:]))+'</p>') if len(lines)>1 else '<p>'+escape(lines[0])+'</p>'
    page(key, title, body+'</article>')

(OUT / '_headers').write_text('''/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  X-Frame-Options: DENY
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Content-Security-Policy: default-src 'self'; img-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; form-action 'self'; base-uri 'none'
  Cache-Control: public, max-age=300
''')
(OUT / 'robots.txt').write_text('User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: https://auv.macseek.cc/sitemap.xml\n')
(OUT / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join('<url><loc>'+CONFIG['origin']+'/'+p+'</loc></url>' for p in ['', 'guide/', 'feedback/', 'privacy/', 'terms/', 'updates/'])+'</urlset>')
print('Built website/dist: 7 pages, local assets, shared legal text')

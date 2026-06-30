#!/usr/bin/env python3
"""Patch noVNC vnc_lite.html to auto-reconnect on disconnect.

To disable: visit with ?reconnect=false
To adjust delay: ?reconnect_delay=5000 (ms)
"""

with open('/usr/share/novnc/vnc_lite.html') as f:
    content = f.read()

old = 'status("Something went wrong, connection is closed");\n            }\n        }'

new = (
    'status("Something went wrong, connection is closed");\n'
    '            }\n'
    '            const rc=readQueryVariable("reconnect","true");'
    'if(rc==="true"||rc==="1"){'
    'const d=parseInt(readQueryVariable("reconnect_delay","2000"));'
    'status("Reconnecting in "+(d/1000)+"s...");'
    'setTimeout(()=>{'
    'status("Connecting...");'
    'rfb=new RFB(document.getElementById("screen"),url,'
    '{credentials:{password:password}});'
    'rfb.addEventListener("connect",connectedToServer);'
    'rfb.addEventListener("disconnect",disconnectedFromServer);'
    'rfb.addEventListener("credentialsrequired",credentialsAreRequired);'
    'rfb.addEventListener("desktopname",updateDesktopName);'
    'rfb.viewOnly=readQueryVariable("view_only",false);'
    'rfb.scaleViewport=readQueryVariable("scale",false)'
    '},d)}\n'
    '        }'
)

content = content.replace(old, new)

with open('/usr/share/novnc/vnc_lite.html', 'w') as f:
    f.write(content)

print('patched noVNC with reconnect support')

#!/bin/bash
# Generate entitlements.xml for ldid signing
OUTPUTDIR="$1"
TROLLSTORE_JIT_ENT="${2:-0}"

if [ "$TROLLSTORE_JIT_ENT" = "1" ]; then
  # TrollStore: full entitlements including JIT
  cat > "$OUTPUTDIR/entitlements.sideload.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>platform-application</key>
	<true/>
	<key>get-task-allow</key>
	<true/>
	<key>com.apple.p.security.jit-allow</key>
	<true/>
	<key>com.apple.private.cs.debugger</key>
	<true/>
	<key>com.apple.private.skip-library-validation</key>
	<true/>
	<key>com.apple.private.security.container-required</key>
	<true/>
	<key>com.apple.private.security.no-container</key>
	<true/>
	<key>com.apple.private.security.no-sandbox</key>
	<true/>
</dict>
</plist>
EOF
else
  # Standard sideload
  cat > "$OUTPUTDIR/entitlements.sideload.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>platform-application</key>
	<true/>
	<key>com.apple.private.security.container-required</key>
	<true/>
</dict>
</plist>
EOF
fi

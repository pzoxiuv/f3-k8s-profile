cap="1,mount,"
volname="test-$(date +%s)"
volsize="2147483648"
endpoint="unix:///tmp/csi.sock"
target_path="/tmp/targetpath"
params="server=127.0.0.1,share=/"

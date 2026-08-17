from pathlib import Path

p = Path("/usr/lib64/python3.14/site-packages/pyanaconda/ui/lib/storage.py")
s = p.read_text()

old = '''    elif flags.automatedInstall:
        # Get all disks.
        device_tree = STORAGE.get_proxy(DEVICE_TREE)
        all_disks = device_tree.GetDisks()

        # Select all disks.
        selected_disks = [d for d in all_disks if d not in ignored_disks]
        disk_select_proxy.SelectedDisks = selected_disks
        log.debug("Selecting all disks by default: %s", ",".join(selected_disks))
'''

new = '''    elif flags.automatedInstall:
        # Safety policy for the MacPro7,1 installer:
        # never preselect storage devices.
        #
        # The installer is intentionally interactive for storage even though
        # the ISO contains Kickstart configuration. The user must explicitly
        # choose the installation target.
        selected_disks = []
        disk_select_proxy.SelectedDisks = []
        log.debug("Leaving all disks unselected by default")
'''

if old not in s:
    raise SystemExit("ERROR: expected Anaconda default-selection block not found")

p.write_text(s.replace(old, new))
print("Patched:", p)

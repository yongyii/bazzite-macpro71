from pathlib import Path

p = Path("/usr/lib64/python3.14/site-packages/pyanaconda/ui/tui/spokes/storage.py")
s = p.read_text()

old = '''        # show this info for all disks
        format_str = "{}: {} ({})".format(
            data.attrs.get("model", "DISK"),
            Size(data.size),
            data.name
        )

        # now append all additional attributes to our string
        disk_attrs = filter(None, map(data.attrs.get, (
            "wwn", "bus-id", "fcp-lun", "wwpn", "hba-id"
        )))

        for attr in disk_attrs:
            format_str += ", %s" % attr

        return format_str
'''

new = '''        # Show enough identity information to safely distinguish
        # same-size and same-model disks.
        model = data.attrs.get("model", "DISK")
        serial = data.attrs.get("serial")
        wwn = data.attrs.get("wwn")
        bus_id = data.attrs.get("bus-id")

        format_str = "{}: {} ({})".format(
            model,
            Size(data.size),
            data.name
        )

        if serial:
            format_str += ", Serial: {}".format(serial)

        if wwn:
            format_str += ", WWN: {}".format(wwn)

        if bus_id:
            format_str += ", Bus: {}".format(bus_id)

        return format_str
'''

if old not in s:
    raise SystemExit("ERROR: expected Anaconda disk display block not found")

p.write_text(s.replace(old, new))
print("Patched:", p)

def rgb_int_to_hex(rgb_int):
    return "#{:06x}".format(rgb_int & 0xFFFFFF)


def generate_readings_id(db):
    from model import ReadingsInfo  # avoid circular import

    latest = db.query(ReadingsInfo).order_by(
        ReadingsInfo.ReadingsID.desc()).first()

    if not latest or not latest.ReadingsID.startswith("R-"):
        return "R-00001"

    try:
        current_num = int(latest.ReadingsID.split("-")[1])
    except (IndexError, ValueError):
        current_num = 0

    return f"R-{current_num + 1:05d}"

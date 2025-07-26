def rgb_int_to_hex(rgb_int):
    return "#{:06x}".format(rgb_int & 0xFFFFFF)

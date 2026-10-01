from std.os import abort

from .endian_order import EndianOrder


# host_order — the host's byte order, resolved at compile time.
def host_order() -> EndianOrder:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# host_order — the host's byte order, resolved at compile time.
# Signature:
#   def host_order() -> EndianOrder
# What it does:
#   Reports which byte order this build target uses, as an EndianOrder. It is
#   fixed at compile time (from the standard library's host-order predicates),
#   so it costs nothing at run time and there is no runtime probe and no global
#   switch. It never returns a third value: mixed-endian hosts are not a
#   supported target. host_order() equals EndianOrder.NATIVE.
# Returns:
#   EndianOrder.LITTLE on a little-endian target, EndianOrder.BIG on a
#   big-endian target; owned by the caller.
# Errors:
#   none — it is a total query.
# Example:
#   var order = host_order()
#   if order == EndianOrder.LITTLE:
#       print("little-endian host")
#   else:
#       print("big-endian host")
#   # host_order() == EndianOrder.NATIVE
# API-DOCS-END

from akku.net_ip import IpAddress as _IpAddress
from akku.io_core import IoError as _IoError


struct SocketAddress(Copyable, Movable, Deinitable, Equatable, Writable):
    var _address: _IpAddress
    var _port: UInt16
    var _scope_id: UInt32

    def __init__(out self, address: _IpAddress, port: UInt16,
                 scope_id: UInt32 = 0) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def address(self) -> _IpAddress:
        abort("MojoAkku: this API is not yet implemented")

    def port(self) -> UInt16:
        abort("MojoAkku: this API is not yet implemented")

    def scope_id(self) -> UInt32:
        abort("MojoAkku: this API is not yet implemented")

    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# SocketAddress — numeric IP, port and optional IPv6 scope.
# Signature:
#   struct SocketAddress(Copyable, Movable, Deinitable, Equatable, Writable):
#       def __init__(out self, address: IpAddress, port: UInt16,
#                    scope_id: UInt32 = 0) raises IoError
#       def address(self) -> IpAddress
#       def port(self) -> UInt16
#       def scope_id(self) -> UInt32
#       def __eq__(self, other: Self) -> Bool
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Copies the numeric IP; stores host-order port and scope ID. Port 0–65535
#   is representable without narrowing arbitrary Int input. IPv4 scope must be zero.
#   Accessor values do not borrow from the endpoint. Equality includes IP, port and
#   scope. Writable produces `127.0.0.1:80`, `[::1]:80`, or `[fe80::1%3]:80` with
#   numeric nonzero scope inside brackets. Formatting performs no lookup and never
#   round-trips through a hostname. No I/O, interruption, EOF or close behavior applies.
# Returns:
#   An independent copyable endpoint value; accessors return independent values.
# Errors:
#   Constructor raises IoError(OTHER, "address", opaque detail) for IPv4 scope.
#   Accessors, equality and formatting cannot fail.
# Example:
#   from akku.net_ip import IpAddress, Ipv4Address
#   from akku.net_socket import SocketAddress
#   var endpoint = SocketAddress(IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001)), 8080)
#   print(endpoint)  # 127.0.0.1:8080
# API-DOCS-END

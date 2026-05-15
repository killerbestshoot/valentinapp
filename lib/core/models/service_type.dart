enum ServiceType { moncash, natcash, minit, westernUnion, camTransfer }

String serviceLabel(ServiceType s) {
  switch (s) {
    case ServiceType.moncash:
      return 'MonCash';
    case ServiceType.natcash:
      return 'NatCash';
    case ServiceType.minit:
      return 'Minit';
    case ServiceType.westernUnion:
      return 'Western Union';
    case ServiceType.camTransfer:
      return 'CAM Transfer';
  }
}

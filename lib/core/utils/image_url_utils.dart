String normalizeImageUrl(Object? value) {
  if (value == null) return '';

  var url = value.toString().trim();
  if (url.isEmpty || url == 'null') return '';

  if (url.startsWith('https://')) return url;
  if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
  if (url.startsWith('//')) return 'https:$url';

  return '';
}

String shipmentImageUrl(Map<dynamic, dynamic>? shipment) {
  if (shipment == null) return '';
  return normalizeImageUrl(shipment['image_url']);
}

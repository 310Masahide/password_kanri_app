module ApplicationHelper
  # QR コードを、画像（data: で始まる URL）にする
  # html_safe で SVG をそのまま埋め込まずに済むので、画面に余計なタグが入り込む心配がない
  def qr_code_data_url(qr_code)
    svg = qr_code.as_svg(module_size: 4, use_path: true, viewbox: true)
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end


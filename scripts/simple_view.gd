@tool
extends Control

@onready var _download: DialGauge = $Margin/Body/Dials/DownloadCol/Download
@onready var _upload: DialGauge = $Margin/Body/Dials/UploadCol/Upload
@onready var _ping: DialGauge = $Margin/Body/Dials/PingCol/Ping


func _ready() -> void:
	($Chrome as Panel).add_theme_stylebox_override("panel", NovaTheme.frame_style())
	var body: VBoxContainer = $Margin/Body
	body.add_theme_constant_override("separation", 8)
	var dials: HBoxContainer = $Margin/Body/Dials
	dials.add_theme_constant_override("separation", 12)
	for column_path in ["DownloadCol", "UploadCol", "PingCol"]:
		var column := dials.get_node(column_path) as VBoxContainer
		column.alignment = BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation", 2)

	NovaTheme.style_label(
		$Margin/Body/Wordmark,
		NovaTheme.tracked(NovaTheme.LIGHT, 16),
		28,
		NovaPalette.COPPER_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var caption_font := NovaTheme.tracked(NovaTheme.MEDIUM, 2)
	for node in [
		$Margin/Body/Dials/DownloadCol/DownloadCaption,
		$Margin/Body/Dials/UploadCol/UploadCaption,
		$Margin/Body/Dials/PingCol/PingCaption,
	]:
		NovaTheme.style_label(node, caption_font, 18, NovaPalette.COPPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER)

	($Margin/Body/Rule as ColorRect).color = NovaPalette.BORDER
	var status_font := NovaTheme.tracked(NovaTheme.REGULAR, 1)
	NovaTheme.style_label($Margin/Body/Status/WifiBox/WifiLabel, status_font, 16, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($Margin/Body/Status/EthBox/EthLabel, status_font, 16, NovaPalette.STEEL_LIGHT)
	($Margin/Body/Status as HBoxContainer).add_theme_constant_override("separation", 16)
	($Margin/Body/Status/WifiBox as HBoxContainer).add_theme_constant_override("separation", 10)
	($Margin/Body/Status/EthBox as HBoxContainer).add_theme_constant_override("separation", 10)

	var data := DemoTelemetry.simple()
	_download.value = float(data.download_mbps)
	_upload.value = float(data.upload_mbps)
	_ping.value = float(data.ping_ms)

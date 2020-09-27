extends Node

"""
	100% pure GDScript Mod Player [Godot Mod Player] by Yui Kinomoto @arlez80
"""

class_name ModPlayer

# -----------------------------------------------------------------------------
# Import
const Mod = preload( "Mod.gd" )

# -------------------------------------------------------
# 定数
const mod_master_bus_name:String = "arlez80_GMP_MASTER_BUS"
const mod_channel_bus_name:String = "arlez80_GMP_CHANNEL_BUS%d"

# -----------------------------------------------------------------------------
# Classes
class GodotModPlayerChannelAudioEffect:
	var ae_panner:AudioEffectPanner = null
	#var ae_reverb:AudioEffectReverb = null
	#var ae_chorus:AudioEffectChorus = null

class GodotModPlayerChannelStatus:
	var asp:AudioStreamPlayer

	var note_on:bool
	var number:int
	var sample_number:int
	var key_number:int

	func _init( _number:int ):
		self.note_on = false
		self.number = _number
		self.asp = AudioStreamPlayer.new( )
		self.asp.bus = mod_channel_bus_name % self.number

# -----------------------------------------------------------------------------
# Export

# ファイル
export (String, FILE, "*.mod") var file:String = "" setget set_file
# 再生中か？
export (bool) var playing:bool = false
# 再生速度
export (float) var play_speed:float = 1.0
# 音量
export (float, -144, 0) var volume_db:float = -20.0 setget set_volume_db
# キーシフト（未実装）
#export (int) var key_shift:int = 0
# ループフラグ
export (bool) var loop:bool = false
# mix_target same as AudioStreamPlayer's one
export (int, "MIX_TARGET_STEREO", "MIX_TARGET_SURROUND", "MIX_TARGET_CENTER") var mix_target:int = AudioStreamPlayer.MIX_TARGET_STEREO
# bus same as AudioStreamPlayer's one
export (String) var bus:String = "Master"
# NTSC mode
export (bool) var ntsc_mode:bool = false setget set_ntsc_mode

# -----------------------------------------------------------------------------
# 変数

# Modデータ
var mod_data:Mod.Mod = null setget set_mod_data
# ノート毎秒
var note_per_second:float = 0.02
# 次のノートへの秒数
var next_note_remain_second:float = 0.0
# 位置（秒）
var position:float = 0.0
# 曲位置
var song_position:int = 0
# パターン内位置
var pattern_position:int = 0
# チャンネル
var channel_status:Array = []
# Modチャンネルエフェクト
var channel_audio_effects:Array = []
# サンプリングレート化
var to_sample_rate:float = 7093789.2

# -----------------------------------------------------------------------------
# シグナル

signal looped

"""
	準備
"""
func _ready( ):
	if AudioServer.get_bus_index( self.mod_master_bus_name ) == -1:
		AudioServer.add_bus( -1 )
		var mod_master_bus_idx:int = AudioServer.get_bus_count( ) - 1
		AudioServer.set_bus_name( mod_master_bus_idx, self.mod_master_bus_name )
		AudioServer.set_bus_send( mod_master_bus_idx, self.bus )
		AudioServer.set_bus_volume_db( AudioServer.get_bus_index( self.mod_master_bus_name ), self.volume_db )

		for i in range( 0, 4 ):
			AudioServer.add_bus( -1 )
			var mod_channel_bus_idx:int = AudioServer.get_bus_count( ) - 1
			AudioServer.set_bus_name( mod_channel_bus_idx, self.mod_channel_bus_name % i )
			AudioServer.set_bus_send( mod_channel_bus_idx, self.mod_master_bus_name )
			AudioServer.set_bus_volume_db( mod_channel_bus_idx, 0.0 )

			var cae: = GodotModPlayerChannelAudioEffect.new( )
			cae.ae_panner = AudioEffectPanner.new( )
			AudioServer.add_bus_effect( mod_channel_bus_idx, cae.ae_panner )
			self.channel_audio_effects.append( cae )

	if self.playing:
		self.play( )

"""
	通知
"""
func _notification( what:int ):
	# 破棄時
	if what == NOTIFICATION_PREDELETE:
		pass
		#AudioServer.remove_bus( AudioServer.get_bus_index( self.mod_master_bus_name ) )
		#for i in range( 0, 16 ):
		#	AudioServer.remove_bus( AudioServer.get_bus_index( self.midi_channel_bus_name % i ) )

"""
	再生前の初期化
"""
func _prepare_to_play( ):
	# ファイル読み込み
	if self.mod_data == null:
		var mod_reader: = Mod.new( )
		self.mod_data = mod_reader.read_file( self.file )

	if self.channel_status != null:
		for t in self.channel_status:
			self.remove_child( t.asp )

	self.channel_status = []
	for i in range( self.mod_data.channel_count ):
		var cs: = GodotModPlayerChannelStatus.new( i )
		self.add_child( cs.asp )
		self.channel_status.append( cs )

"""
	再生
	@param	from_position
"""
func play( from_position:float = 0.0 ):
	self._prepare_to_play( )
	self.playing = true
	if from_position == 0.0:
		self.position = 0.0
		self.song_position = 0
		self.pattern_position = 0
		self.note_per_second = 0.02
		self.next_note_remain_second = 0.0
	else:
		self.seek( from_position )

"""
	シーク: TODO
"""
func seek( to_position:float ):
	self._stop_all_notes( )

"""
	停止
"""
func stop( ):
	self._stop_all_notes( )
	self.playing = false

"""
	ファイル変更
"""
func set_file( path:String ):
	file = path
	self.mod_data = null

"""
	Modデータ更新
"""
func set_mod_data( md ):
	mod_data = md

"""
	音量設定
"""
func set_volume_db( vdb:float ):
	volume_db = vdb
	AudioServer.set_bus_volume_db( AudioServer.get_bus_index( self.mod_master_bus_name ), self.volume_db )

"""
	
"""
func set_ntsc_mode( _ntsc_mode:bool ):
	ntsc_mode = _ntsc_mode
	if ntsc_mode:
		self.to_sample_rate = 7159090.5
	else:
		self.to_sample_rate = 7093789.2

"""
	全音を止める
"""
func _stop_all_notes( ):
	for t in self.channel_status:
		t.asp.stop( )
		t.note_on = false

"""
	毎フレーム処理
"""
func _process( delta:float ):
	if self.mod_data != null:
		if self.playing:
			self.position += delta
			self.next_note_remain_second -= delta
			if self.next_note_remain_second <= 0.0:
				self._process_note( )
				self.next_note_remain_second = self.note_per_second

	self._update_channels( )

"""
	トラック処理
"""
func _process_note( ):
	var jump:bool = false

	var pattern_line:Array = self.mod_data.patterns[self.mod_data.song_positions[self.song_position]][self.pattern_position]

	for channel in self.channel_status:
		var pattern_node:Mod.ModPatternNote = pattern_line[channel.number]
		#printt( channel.number, pattern_node.sample_number, pattern_node.key_number, pattern_node.effect_command )

		if 0 < pattern_node.key_number:
			channel.sample_number = pattern_node.sample_number
			channel.key_number = pattern_node.key_number

		#match ( channel >> 12 ) & 0x0F:
		#	0x00:
		#		channel.

	if not jump:
		self.pattern_position += 1
		if 64 <= self.pattern_position:
			self.pattern_position = 0
			self.song_position += 1

"""
	各チャンネルをアップデート
"""
func _update_channels( ):
	for channel in self.channel_status:
		pass

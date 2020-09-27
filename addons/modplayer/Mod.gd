"""
	MOD reader by Yui Kinomoto @arlez80
"""

class Mod:
	var name:String
	var song_length:int
	var unknown_number:int
	var channel_count:int
	var song_positions:Array
	var magic:String
	var patterns:Array
	var samples:Array

class ModSample:
	var data:PoolByteArray
	var name:String
	var length:int
	var fine_tune:int
	var volume:int
	var loop_start:int
	var loop_length:int

class ModPatternNote:
	var sample_number:int
	var key_number:int
	var effect_command:int

"""
	ファイルから読み込み
	@param	path	File path
	@return	smf
"""
func read_file( path:String ) -> Mod:
	var f:File = File.new( )

	if not f.file_exists( path ):
		print( "file %s is not found" % path )
		breakpoint

	f.open( path, f.READ )
	var stream:StreamPeerBuffer = StreamPeerBuffer.new( )
	stream.set_data_array( f.get_buffer( f.get_len( ) ) )
	stream.big_endian = true
	f.close( )

	return self._read( stream )

"""
	配列から読み込み
	@param	data	PoolByteArray
	@return	smf
"""
func read_data( data:PoolByteArray ) -> Mod:
	var stream:StreamPeerBuffer = StreamPeerBuffer.new( )
	stream.set_data_array( data )
	stream.big_endian = true
	return self._read( stream )

"""
	読み込み
	@param	stream
	@return	smf
"""
func _read( stream:StreamPeerBuffer ) -> Mod:
	var mod:Mod = Mod.new( )
	mod.name = self._read_string( stream, 20 )
	mod.samples = self._read_sample_informations( stream )
	mod.song_length = stream.get_u8( )
	mod.unknown_number = stream.get_u8( )
	mod.song_positions = stream.get_partial_data( 128 )[1]
	var max_song_position:int = 0
	for sp in mod.song_positions:
		if max_song_position < sp:
			max_song_position = sp

	mod.magic = self._read_string( stream, 4 )
	var channel_count:int = 4
	match mod.magic:
		"6CHN":
			channel_count = 6
		"FLT8", "8CHN", "CD81", "OKTA":
			channel_count = 8
		"16CN":
			channel_count = 16
		"32CN":
			channel_count = 32
		_:
			# print( "Unknown magic" )
			# breakpoint
			pass
	mod.channel_count = channel_count

	mod.patterns = self._read_patterns( stream, max_song_position, channel_count )
	self._read_sample_data( stream, mod.samples )

	return mod

"""
	サンプルのデータを読み込む
"""
func _read_sample_informations( stream:StreamPeerBuffer ) -> Array:
	var samples:Array = []

	for i in range( 0, 31 ):
		var sample:ModSample = ModSample.new( )
		sample.name = self._read_string( stream, 22 )
		sample.length = stream.get_u16( ) * 2
		sample.fine_tune = stream.get_u8( ) & 0x0F
		if 0x08 < sample.fine_tune:
			sample.fine_tune = 0x10 - sample.fine_tune
		sample.volume = stream.get_u8( )
		sample.loop_start = stream.get_u16( ) * 2
		sample.loop_length = stream.get_u16( ) * 2

		samples.append( sample )

	return samples

"""
	パターンを読み込む
"""
func _read_patterns( stream:StreamPeerBuffer, max_position:int, channels:int ) -> Array:
	var patterns:Array = []

	for position in range( 0, max_position ):
		var pattern:Array = []
		for i in range( 0, 64 ):
			var line:Array = []
			for ch in range( 0, channels ):
				var v1:int = stream.get_u16( )
				var v2:int = stream.get_u16( )
				var mod_pattern_note: = ModPatternNote.new( )
				mod_pattern_note.sample_number = ( ( v1 >> 8 ) & 0xF0 ) | ( ( v2 >> 12 ) & 0x0F )
				mod_pattern_note.key_number = v1 & 0x0FFF
				mod_pattern_note.effect_command = v2 & 0x0FFF
				line.append( mod_pattern_note )
			pattern.append( line )
		patterns.append( pattern )

	return patterns

"""
	波形データ読み込む
"""
func _read_sample_data( stream:StreamPeerBuffer, samples:Array ):
	for sample in samples:
		sample.data = stream.get_partial_data( sample.length )[1]

"""
	文字列の読み込み
	@param	stream	Stream
	@param	size	string size
	@return string
"""
func _read_string( stream:StreamPeerBuffer, size:int ) -> String:
	return stream.get_partial_data( size )[1].get_string_from_ascii( )

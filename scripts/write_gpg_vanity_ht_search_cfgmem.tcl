set proj_dir [file normalize "build/vivado_gpg_vanity_ht_search_synth"]
set bit_file "$proj_dir/gpg_vanity_ht_search_top.bit"
set mcs_file "$proj_dir/gpg_vanity_ht_search_top_flash.mcs"
set bin_file "$proj_dir/gpg_vanity_ht_search_top_flash.bin"

open_checkpoint "$proj_dir/routed.dcp"
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS FALSE [current_design]
write_bitstream -force $bit_file

write_cfgmem -force -format mcs -interface SPIx4 -size 32 \
    -loadbit "up 0x00000000 $bit_file" $mcs_file
write_cfgmem -force -format bin -interface SPIx4 -size 32 \
    -loadbit "up 0x00000000 $bit_file" $bin_file

puts "CFG_BIT $bit_file"
puts "CFG_MCS $mcs_file"
puts "CFG_BIN $bin_file"

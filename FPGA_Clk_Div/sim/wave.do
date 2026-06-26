onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /TB_Baud_Clk_Divider_50/iClk
add wave -noupdate /TB_Baud_Clk_Divider_50/iResetN
add wave -noupdate /TB_Baud_Clk_Divider_50/oClk
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1086361 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {4270889 ps}

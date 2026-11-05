// Included inside a testbench module. Enable with +WAVES, or DUMP_FSDB for VCS.
`ifdef DUMP_FSDB
initial begin : capture_fsdb
    string waveform_path;
    if (!$value$plusargs("FSDB=%s", waveform_path)) waveform_path = "build/waves.fsdb";
    $fsdbDumpfile(waveform_path);
    $fsdbDumpvars(0);
end
`else
initial begin : capture_vcd
    string waveform_path;
    if ($test$plusargs("WAVES")) begin
        if (!$value$plusargs("VCD=%s", waveform_path)) waveform_path = "build/waves.vcd";
        $dumpfile(waveform_path);
        $dumpvars(0);
    end
end
`endif

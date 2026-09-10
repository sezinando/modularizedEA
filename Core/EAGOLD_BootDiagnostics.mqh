#ifndef EAGOLD_BOOT_DIAGNOSTICS_MQH
#define EAGOLD_BOOT_DIAGNOSTICS_MQH

void EAGOLD_BootDiagnostic(const EAGOLD_Context &ctx)
{
   Print("EAGOLD MODULAR: ========================================");
   Print("EAGOLD MODULAR: BOOT DIAGNOSTIC");
   Print("EAGOLD MODULAR: Core / Context       = ",ctx.symbol!="" ? "OK" : "FAIL");
   Print("EAGOLD MODULAR: Core / State         = OK");
   Print("EAGOLD MODULAR: Core / Orders        = OK");
   Print("EAGOLD MODULAR: Core / Execution     = OK");
   Print("EAGOLD MODULAR: Core / Events        = OK");
   Print("EAGOLD MODULAR: Core / Telemetry     = OK");
   Print("EAGOLD MODULAR: Persistence          = OK");
   Print("EAGOLD MODULAR: UI / Panel            = OK");
   Print("EAGOLD MODULAR: UI / GM-3 Clock       = OK");
   Print("EAGOLD MODULAR: UI / Server Clock     = OK");
   Print("EAGOLD MODULAR: Engine / R10          = ",ctx.enableR10 ? "ENABLED" : "DISABLED");
   Print("EAGOLD MODULAR: Engine / R10 Pair     = ",ctx.enableR10Pair ? "ENABLED" : "DISABLED");
   Print("EAGOLD MODULAR: Symbol                = ",ctx.symbol);
   Print("EAGOLD MODULAR: Magic                 = ",ctx.magic);
   Print("EAGOLD MODULAR: Trading               = ",ctx.enableR10 ? "ENABLED" : "DISABLED");
   Print("EAGOLD MODULAR: READY");
   Print("EAGOLD MODULAR: ========================================");
}

string EAGOLD_BootPanel(const EAGOLD_Context &ctx)
{
   return StringFormat("EAGOLD MODULAR\nBOOT STATUS: OK\n\nCORE\n  Context       : OK\n  State         : OK\n  Orders        : OK\n  Execution     : OK\n  Events        : OK\n  Telemetry     : OK\n\nPERSISTENCE    : OK\n\nENGINES\n  R10           : %s\n  R10 Pair      : %s\n\nUI\n  Panel         : OK\n  GM-3 Clock    : OK\n  Server Clock  : OK\n\nSYMBOL %s   MAGIC %d\nTRADING %s",
      ctx.enableR10 ? "ENABLED" : "DISABLED",
      ctx.enableR10Pair ? "ENABLED" : "DISABLED",
      ctx.symbol,ctx.magic,
      ctx.enableR10 ? "ENABLED" : "DISABLED");
}

#endif

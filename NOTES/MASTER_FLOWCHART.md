# FCU Guidance Management System - Master Flowchart

This diagram consolidates all major modules and user interactions into a single unified workspace flow.

```mermaid
flowchart TB
    %% Entry Points
    Start([User Launch App]) --> AuthCheck{Session Valid?}
    
    %% Public/Guest Flow
    AuthCheck -- No --> Landing[Landing Page]
    Landing --> PubChat[Chat Hub / AI Support]
    Landing --> AnonRep[Anonymous Report]
    Landing --> Auth((Sign In / Sign Up))
    
    AnonRep --> CodeGen[Generate Case Code]
    CodeGen --> TrackAnon[Track via Case Code]
    
    %% Authentication & Redirection
    Auth --> RoleSwitch{Identify Role}
    AuthCheck -- Yes --> RoleSwitch
    
    %% User Specific Dashboards
    RoleSwitch -- Student --> SDash[Student Dashboard]
    RoleSwitch -- Teacher --> TDash[Teacher Dashboard]
    RoleSwitch -- Counselor --> CDash[Counselor Dashboard]
    RoleSwitch -- Dean --> DDash[Dean Dashboard]
    RoleSwitch -- Admin --> ADash[Admin Dashboard]
    
    %% Operational Workflows
    SDash --> SActions{Student Actions}
    SActions --> SRep[Submit Official Report]
    SActions --> SReq[Request Counseling]
    SActions --> SChat[AI/Human Chat Support]
    
    TDash --> TActions{Teacher Actions}
    TActions --> TRev[Review Reports]
    TActions --> TFwd[Forward to Guidance]
    
    CDash --> CActions{Counselor Actions}
    CActions --> CDisc[Case Discovery]
    CActions --> CComm[Live Chat & Messaging]
    CActions --> CSched[Schedule Counseling]
    
    DDash --> DActions{Dean Actions}
    DActions --> DAppr[Approve/Settle Cases]
    DActions --> DAnal[View Analytics]
    
    %% Core Logic Links
    SRep & TFwd --> CDisc
    CDisc --> CSched & CComm
    CSched & CComm --> DAppr
    
    %% Real-time Sync
    DAppr -- Status Update --> Notif[Real-time Notification System]
    Notif --> SDash & TDash & CDash
    
    %% Footer
    ADash --> Sys[System Backup/Restore]
```

## How to Read This Flowchart
- **Rectangles:** Pages or Modules.
- **Diamonds:** Decision points or Role checks.
- **Ovals:** Start and End points.
- **Multiple Arrows:** Parallel actions or branching logic.
- **Notifications:** The background process that keeps all status updates synced in real-time.

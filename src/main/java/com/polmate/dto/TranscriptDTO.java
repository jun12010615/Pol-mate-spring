package com.polmate.dto;

import java.sql.Timestamp;

public class TranscriptDTO {

    private int       transcriptId;
    private String    caseId;
    private String    userId;
    private String    originalText;
    private String    aiResult;
    private int       hasContradiction;
    private String    stmtType;
    private String    stmtName;
    private Timestamp createdAt;
    private String    caseName;
    private String    caseStatus;

    public TranscriptDTO() {}

    public int       getTranscriptId()    { return transcriptId; }
    public String    getCaseId()          { return caseId; }
    public String    getUserId()          { return userId; }
    public String    getOriginalText()    { return originalText; }
    public String    getAiResult()        { return aiResult; }
    public int       getHasContradiction(){ return hasContradiction; }
    public String    getStmtType()        { return stmtType; }
    public String    getStmtName()        { return stmtName; }
    public Timestamp getCreatedAt()       { return createdAt; }
    public String    getCaseName()        { return caseName; }
    public String    getCaseStatus()      { return caseStatus; }

    public void setTranscriptId(int v)         { this.transcriptId    = v; }
    public void setCaseId(String v)            { this.caseId          = v; }
    public void setUserId(String v)            { this.userId          = v; }
    public void setOriginalText(String v)      { this.originalText    = v; }
    public void setAiResult(String v)          { this.aiResult        = v; }
    public void setHasContradiction(int v)     { this.hasContradiction= v; }
    public void setStmtType(String v)          { this.stmtType        = v; }
    public void setStmtName(String v)          { this.stmtName        = v; }
    public void setCreatedAt(Timestamp v)      { this.createdAt       = v; }
    public void setCaseName(String v)          { this.caseName        = v; }
    public void setCaseStatus(String v)        { this.caseStatus      = v; }
}

package com.polmate.dto;

public class MypageStatsDTO {

    private int activeCases;
    private int contradictionCount;
    private int completedTranscripts;
    private int totalCases;
    private int totalTranscripts;
    private int relationEdges;

    public MypageStatsDTO() {}

    public int getActiveCases()          { return activeCases; }
    public int getContradictionCount()   { return contradictionCount; }
    public int getCompletedTranscripts() { return completedTranscripts; }
    public int getTotalCases()           { return totalCases; }
    public int getTotalTranscripts()     { return totalTranscripts; }
    public int getRelationEdges()        { return relationEdges; }

    public void setActiveCases(int v)          { this.activeCases          = v; }
    public void setContradictionCount(int v)   { this.contradictionCount   = v; }
    public void setCompletedTranscripts(int v) { this.completedTranscripts = v; }
    public void setTotalCases(int v)           { this.totalCases           = v; }
    public void setTotalTranscripts(int v)     { this.totalTranscripts     = v; }
    public void setRelationEdges(int v)        { this.relationEdges        = v; }
}

package com.polmate.dto;

import java.sql.Timestamp;

public class UserDTO {

    private String userId;
    private String userPw;
    private String userName;
    private String userPhone;
    private String userOrg;
    private String userRank;
    private String userDept;
    private String badgeNum;
    private Timestamp createdAt;
    private Integer deptId;

    public UserDTO() {}

    public String getUserId()       { return userId; }
    public String getUserPw()       { return userPw; }
    public String getUserName()     { return userName; }
    public String getUserPhone()    { return userPhone; }
    public String getUserOrg()      { return userOrg; }
    public String getUserRank()     { return userRank; }
    public String getUserDept()     { return userDept; }
    public String getBadgeNum()     { return badgeNum; }
    public Timestamp getCreatedAt() { return createdAt; }
    public Integer getDeptId()      { return deptId; }

    public void setUserId(String userId)          { this.userId    = userId; }
    public void setUserPw(String userPw)          { this.userPw    = userPw; }
    public void setUserName(String userName)      { this.userName  = userName; }
    public void setUserPhone(String userPhone)    { this.userPhone = userPhone; }
    public void setUserOrg(String userOrg)        { this.userOrg   = userOrg; }
    public void setUserRank(String userRank)      { this.userRank  = userRank; }
    public void setUserDept(String userDept)      { this.userDept  = userDept; }
    public void setBadgeNum(String badgeNum)      { this.badgeNum  = badgeNum; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
    public void setDeptId(Integer deptId)         { this.deptId    = deptId; }
}

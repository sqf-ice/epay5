/******************************************************************
** Copyright(C)2006 - 2008联迪商用设备有限公司
** 主要内容：易收付平台金融交易处理模块 预授权完成交易
** 创 建 人：冯炜
** 创建日期：2012-11-14
**
** $Revision: 1.4 $
** $Log: Confirm.ec,v $
** Revision 1.4  2013/07/02 01:15:11  fengw
**
** 1、增加终端号赋值语句。
**
** Revision 1.3  2012/12/11 05:09:27  fengw
**
** 1、修改授权码赋值语句。
**
** Revision 1.2  2012/12/04 01:24:28  fengw
**
** 1、替换ErrorLog为WriteLog。
**
** Revision 1.1  2012/11/23 09:09:16  fengw
**
** 金融交易处理模块初始版本
**
** Revision 1.1  2012/11/21 07:20:46  fengw
**
** 金融交易处理模块初始版本
**
*******************************************************************/

#define _EXTERN_

#include "finatran.h"

EXEC SQL BEGIN DECLARE SECTION;
    EXEC SQL INCLUDE SQLCA;
    char    szRetriRefNum[12+1];            /* 后台检索参考号 */
    char    szOldRetriRefNum[12+1];         /* 原后台检索参考号 */
    char    szReturnCode[2+1];              /* 平台返回码 */
    char    szHostRetCode[6+1];             /* 后台返回码 */
    char    szHostRetMsg[40+1];             /* 后台返回错误信息 */
    char    szAuthCode[6+1];                /* 授权码 */
    char    szHostDate[8+1];                /* 平台交易日期 */
    char    szHostTime[6+1];                /* 平台交易时间 */
    char    szSettleDate[8+1];              /* 结算日期 */
    int     iBatchNo;                       /* 批次号 */
    double  dAmount;                        /* 交易金额 */
    char    szBankID[11+1];                 /* 银行标识号 */
    char    szShopNo[15+1];                 /* 商户号 */
    char    szPosNo[15+1];                  /* 终端号 */
    int     iPosTrace;                      /* 终端流水号 */
    int     iOldPosTrace;                   /* 原终端流水号 */
    int     iSysTrace;                      /* 平台流水号 */
    int     iTransType;                     /* 交易类型 */
    char    szPan[19+1];                    /* 转出卡号 */
    char    szAccount2[19+1];               /* 转入卡号 */
    char    szPosDate[8+1];                 /* POS交易日期 */
    char    szCancelFlag[1+1];              /* 撤销标志 */
    char    szRecoverFlag[1+1];             /* 冲正标志 */
    char    szPosSettle[1+1];               /* 结算标志 */
EXEC SQL END DECLARE SECTION;

/****************************************************************
** 功    能：交易预处理
** 输入参数：
**        ptApp           app结构
** 输出参数：
**        ptApp           app结构
** 返 回 值：
**        SUCC            处理成功
**        FAIL            处理失败
** 作    者：
**        fengwei
** 日    期：
**        2012/11/09
** 调用说明：
**
** 修改日志：
****************************************************************/
int ConfirmPreTreat(T_App *ptApp)
{
    /* 参数赋值 */
    memset(szShopNo, 0, sizeof(szShopNo));
    memset(szPosNo, 0, sizeof(szPosNo));
    memset(szPosDate, 0, sizeof(szPosDate));

    strcpy(szShopNo, ptApp->szShopNo);
    strcpy(szPosNo, ptApp->szPosNo);
    strcpy(szPosDate, ptApp->szInDate);
    iPosTrace = ptApp->lPosTrace;
    iTransType = PRE_AUTH;
    iOldPosTrace = ptApp->lOldPosTrace;

    /* 查询原流水记录 */
    memset(szOldRetriRefNum, 0, sizeof(szOldRetriRefNum));
    memset(szHostDate, 0, sizeof(szHostDate));
    memset(szHostTime, 0, sizeof(szHostTime));
    memset(szAccount2, 0, sizeof(szAccount2));
    memset(szPan, 0, sizeof(szPan));
    memset(szReturnCode, 0, sizeof(szReturnCode));
    memset(szCancelFlag, 0, sizeof(szCancelFlag));
    memset(szRecoverFlag, 0, sizeof(szRecoverFlag));
    memset(szPosSettle, 0, sizeof(szPosSettle));
    memset(szAuthCode, 0, sizeof(szAuthCode));


    EXEC SQL
        SELECT retri_ref_num, sys_trace, auth_code, amount, host_time, host_date,
               account2, pan, return_code, cancel_flag, recover_flag, pos_settle
        INTO :szOldRetriRefNum, :iSysTrace, :szAuthCode, :dAmount,
             :szHostDate, :szHostTime, :szAccount2, :szPan,
             :szReturnCode, :szCancelFlag, :szRecoverFlag, :szPosSettle
        FROM history_ls
        WHERE shop_no = :szShopNo AND pos_no = :szPosNo AND
              pos_trace = :iOldPosTrace AND pos_date = :szPosDate AND trans_type = :iTransType;
    if(SQLCODE == SQL_NO_RECORD)
    {
        EXEC SQL
            SELECT retri_ref_num, sys_trace, auth_code, amount, host_time, host_date,
                   account2, pan, return_code, cancel_flag, recover_flag, pos_settle
            INTO :szOldRetriRefNum, :iSysTrace, :szAuthCode, :dAmount,
                 :szHostDate, :szHostTime, :szAccount2, :szPan,
                 :szReturnCode, :szCancelFlag, :szRecoverFlag, :szPosSettle
            FROM posls
            WHERE shop_no = :szShopNo AND pos_no = :szPosNo AND
                  pos_trace = :iOldPosTrace AND pos_date = :szPosDate AND trans_type = :iTransType;
        if(SQLCODE == SQL_NO_RECORD)
        {
            strcpy(ptApp->szRetCode, ERR_TRANS_NOT_EXIST);

            WriteLog(ERROR, "原交易流水流水 商户[%s] 终端[%s] POS流水[%d] POS交易日期[%s] 不存在!SQLCODE=%d SQLERR=%s",
                     szShopNo, szPosNo, iOldPosTrace, szPosDate, SQLCODE, SQLERR);

            return FAIL;
        }
        else if(SQLCODE)
        {
            strcpy(ptApp->szRetCode, ERR_SYSTEM_ERROR);

            WriteLog(ERROR, "查询原交易流水流水 商户[%s] 终端[%s] POS流水[%d] POS交易日期[%s] 失败!SQLCODE=%d SQLERR=%s",
                     szShopNo, szPosNo, iOldPosTrace, szPosDate, SQLCODE, SQLERR);

            return FAIL;
        }
    }
    else if(SQLCODE)
    {
        strcpy(ptApp->szRetCode, ERR_SYSTEM_ERROR);

        WriteLog(ERROR, "查询原交易流水流水 商户[%s] 终端[%s] POS流水[%d] POS交易日期[%s] 失败!SQLCODE=%d SQLERR=%s",
                 szShopNo, szPosNo, iOldPosTrace, szPosDate, SQLCODE, SQLERR);

        return FAIL;
    }

    DelTailSpace(szOldRetriRefNum);
    DelTailSpace(szAuthCode);
    DelTailSpace(szHostDate);
    DelTailSpace(szHostTime);
    DelTailSpace(szAccount2);
    DelTailSpace(szPan);
    DelTailSpace(szReturnCode);
    DelTailSpace(szCancelFlag);
    DelTailSpace(szRecoverFlag);
    DelTailSpace(szPosSettle);

    /* 检查原交易卡号与终端刷卡信息 */
    if(strcmp(ptApp->szPan, szPan) != 0)
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_CARDERR);

        WriteLog(ERROR, "原交易卡号与终端刷卡信息不符 原卡号:[%s] 终端刷卡:[%s]",
                 ptApp->szPan, szPan);

        return FAIL;
    }

    /* 检查原交易授权码与终端输入授权码信息 */
    /* 交易上传授权码存放在商务应用号字段中 */
    strcpy(ptApp->szAuthCode, ptApp->szBusinessCode);
    if(strcmp(ptApp->szAuthCode, szAuthCode) != 0)
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_AUTHERR);

        WriteLog(ERROR, "原交易授权码与终端输入信息不符 原授权码:[%s] 终端输入:[%s]",
                 ptApp->szAuthCode, szAuthCode);

        return FAIL;
    }

    /* 检查原交易状态 */
    /* 是否成功交易 */
    if(memcmp(szReturnCode, "00", 2) != 0)
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_FAIL);

        WriteLog(ERROR, "原交易状态[%s]非成功，预授权无法完成", szReturnCode);

        return FAIL;
    }

    /* 是否已撤销 */
    if(szCancelFlag[0] != 'N')
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_CANCEL);

        WriteLog(ERROR, "原交易已撤销");

        return FAIL;
    }

    /* 是否已冲正 */
    if(szRecoverFlag[0] != 'N')
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_RECOVER);

        WriteLog(ERROR, "原交易已冲正");

        return FAIL;
    }

    /* 是否已结算 */
    if(szPosSettle[0] != 'N')
    {
        strcpy(ptApp->szRetCode, ERR_OLDTRANS_SETTLE);

        WriteLog(ERROR, "原交易已结算");

        return FAIL;
    }

    /* 结果赋值 */
    /* 交易卡号 */
    strcpy(ptApp->szPan, szPan);

    /* 原交易参考号 */
    strcpy(ptApp->szOldRetriRefNum, szOldRetriRefNum);

    /* 授权码 */
    strcpy(ptApp->szAuthCode, szAuthCode);

    /* 原平台流水号 */
    ptApp->lOldSysTrace = iSysTrace;

    /* 预登记流水 */
    if(PreInsertPosls(ptApp) != SUCC)
    {
        return FAIL;
    }

    return SUCC;
}

/****************************************************************
** 功    能：交易后处理
** 输入参数：
**        ptApp           app结构
** 输出参数：
**        ptApp           app结构
** 返 回 值：
**        SUCC            处理成功
**        FAIL            处理失败
** 作    者：
**        fengwei
** 日    期：
**        2012/11/09
** 调用说明：
**
** 修改日志：
****************************************************************/
int ConfirmPostTreat(T_App *ptApp)
{
    /* 更新流水信息 */

    memset(szRetriRefNum, 0, sizeof(szRetriRefNum));
    memset(szReturnCode, 0, sizeof(szReturnCode));
    memset(szHostRetCode, 0, sizeof(szHostRetCode));
    memset(szHostRetMsg, 0, sizeof(szHostRetMsg));
    memset(szAuthCode, 0, sizeof(szAuthCode));
    memset(szHostDate, 0, sizeof(szHostDate));
    memset(szHostTime, 0, sizeof(szHostTime));
    memset(szSettleDate, 0, sizeof(szSettleDate));
    memset(szBankID, 0, sizeof(szBankID));
    memset(szShopNo, 0, sizeof(szShopNo));
    memset(szPosNo, 0, sizeof(szPosNo));
    memset(szPan, 0, sizeof(szPan));
    memset(szPosDate, 0, sizeof(szPosDate));

    /* 参数赋值 */
    strcpy(szRetriRefNum, ptApp->szRetriRefNum);
    strcpy(szReturnCode, ptApp->szRetCode);
    strcpy(szHostRetCode, ptApp->szHostRetCode);
    strcpy(szHostRetMsg, ptApp->szHostRetMsg);
    strcpy(szAuthCode, ptApp->szAuthCode);
    strcpy(szHostDate, ptApp->szHostDate);
    strcpy(szHostTime, ptApp->szHostTime);
    strcpy(szSettleDate, ptApp->szSettleDate);
    strcpy(szBankID, ptApp->szAcqBankId);
    strcpy(szShopNo, ptApp->szShopNo);
    strcpy(szPosNo, ptApp->szPosNo);
    strcpy(szPan, ptApp->szPan);
    strcpy(szPosDate, ptApp->szPosDate);

    iPosTrace = ptApp->lPosTrace;
    iBatchNo = ptApp->lBatchNo;

    EXEC SQL
        UPDATE posls
        SET retri_ref_num = :szRetriRefNum, return_code = :szReturnCode,
            host_ret_code = :szHostRetCode, host_ret_msg = :szHostRetMsg,
            auth_code = :szAuthCode, host_date = :szHostDate, host_time = :szHostTime,
            settle_date = :szSettleDate, batch_no = :iBatchNo, bank_id = :szBankID
        WHERE shop_no = :szShopNo AND pos_no = :szPosNo AND
              pos_trace = :iPosTrace AND pan = :szPan AND
              pos_date = :szPosDate AND recover_flag = 'N' AND pos_settle = 'N';
    if(SQLCODE)
    {
        strcpy(ptApp->szRetCode, ERR_SYSTEM_ERROR);

        WriteLog(ERROR, "更新流水 商户[%s] 终端[%s] POS流水[%d] 卡号:[%s] POS交易日期[%s] 失败!SQLCODE=%d SQLERR=%s",
                 szShopNo, szPosNo, iPosTrace, szPan, szPosDate, SQLCODE, SQLERR);

        return FAIL;
    }

    return SUCC;
}

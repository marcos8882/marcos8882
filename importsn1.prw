#Include "Protheus.ch"
#Include "Rwmake.ch"

/*/{Protheus.doc} U_IMPSN1CSV
Rotina para importacao de arquivo CSV (separado por virgula)
com os campos da tabela SN1 - Ativo Imobilizado.

Fluxo:
1. Usuario seleciona o arquivo CSV;
2. Primeira linha deve conter os nomes dos campos (cabecalho);
3. Cada linha e importada para SN1;
4. Ao final, um log completo e exibido na tela.
@type function
/*/
User Function IMPSN1CSV()
    Local cArquivo     := ""
    Local cConteudo    := ""
    Local aLinhas      := {}
    Local aHeader      := {}
    Local aEstrutura   := {}
    Local aCamposSN1   := {}
    Local aLog         := {}
    Local nLinha       := 0
    Local nSucesso     := 0
    Local nErro        := 0
    Local cDelimitador := ","
    Local lOk          := .T.

    cArquivo := cGetFile("*.csv", "Selecione o arquivo CSV da SN1", 1, "", .F., GETF_LOCALHARD)

    If Empty(cArquivo)
        FWAlertWarning("Importacao cancelada: nenhum arquivo foi selecionado.", "Importacao SN1")
        Return
    EndIf

    If !File(cArquivo)
        FWAlertError("Arquivo nao encontrado: " + cArquivo, "Importacao SN1")
        Return
    EndIf

    cConteudo := MemoRead(cArquivo)

    If Empty(AllTrim(cConteudo))
        FWAlertWarning("Arquivo CSV vazio.", "Importacao SN1")
        Return
    EndIf

    aLinhas := U_SN1SplitLin(cConteudo)

    If Len(aLinhas) <= 1
        FWAlertWarning("CSV sem linhas de dados para importacao.", "Importacao SN1")
        Return
    EndIf

    aHeader := U_SN1CSVLin(aLinhas[1], cDelimitador)

    If Empty(aHeader)
        FWAlertError("Cabecalho do CSV invalido.", "Importacao SN1")
        Return
    EndIf

    dbSelectArea("SN1")
    dbSetOrder(1)
    aEstrutura := dbStruct()

    aCamposSN1 := U_SN1Campos(aEstrutura)

    For nLinha := 2 To Len(aLinhas)
        Local aValores := {}
        Local nCampo   := 0
        Local cMsgErro := ""

        If Empty(AllTrim(aLinhas[nLinha]))
            Loop
        EndIf

        aValores := U_SN1CSVLin(aLinhas[nLinha], cDelimitador)

        If Len(aValores) <> Len(aHeader)
            nErro++
            AAdd(aLog, "Linha " + cValToChar(nLinha) + " ignorada: quantidade de colunas divergente.")
            Loop
        EndIf

        lOk := .T.

        Begin Sequence
            RecLock("SN1", .T.)

            For nCampo := 1 To Len(aHeader)
                Local cCampo   := Upper(AllTrim(aHeader[nCampo]))
                Local uValor   := aValores[nCampo]
                Local nPosCampo := AScan(aCamposSN1, {|c| c == cCampo})

                If nPosCampo > 0
                    FieldPut(nPosCampo, U_SN1ConvCampo(uValor, aEstrutura[nPosCampo, 2]))
                EndIf
            Next nCampo

            MsUnlock()
        Recover Using oErro
            lOk := .F.
            cMsgErro := IIf(ValType(oErro) == "O", oErro:Description, "Erro nao identificado")
            dbRollback()
        End Sequence

        If lOk
            nSucesso++
            AAdd(aLog, "Linha " + cValToChar(nLinha) + " importada com sucesso.")
        Else
            nErro++
            AAdd(aLog, "Linha " + cValToChar(nLinha) + " com erro: " + cMsgErro)
        EndIf
    Next nLinha

    AIns(aLog, 1)
    aLog[1] := "Arquivo: " + cArquivo
    AIns(aLog, 2)
    aLog[2] := "Total de linhas processadas: " + cValToChar((nSucesso + nErro))
    AIns(aLog, 3)
    aLog[3] := "Sucesso: " + cValToChar(nSucesso) + " | Erro: " + cValToChar(nErro)

    FWAlertInfo(U_SN1LogTxt(aLog), "Resultado da importacao SN1")

Return

/*/{Protheus.doc} U_SN1SplitLin
Quebra o conteudo em linhas, tratando CRLF/LF.
@type function
/*/
Static Function U_SN1SplitLin(cConteudo)
    Local cTxt := StrTran(cConteudo, Chr(13), "")
Return HB_ATokens(cTxt, Chr(10))

/*/{Protheus.doc} U_SN1CSVLin
Leitura de uma linha CSV com suporte basico a aspas.
@type function
/*/
Static Function U_SN1CSVLin(cLinha, cSep)
    Local aRet       := {}
    Local cAtual     := ""
    Local lEntreAspa := .F.
    Local nPos       := 0
    Local cChar      := ""

    For nPos := 1 To Len(cLinha)
        cChar := SubStr(cLinha, nPos, 1)

        If cChar == '"'
            If lEntreAspa .And. nPos < Len(cLinha) .And. SubStr(cLinha, nPos + 1, 1) == '"'
                cAtual += '"'
                nPos++
            Else
                lEntreAspa := !lEntreAspa
            EndIf

        ElseIf cChar == cSep .And. !lEntreAspa
            AAdd(aRet, AllTrim(cAtual))
            cAtual := ""

        Else
            cAtual += cChar
        EndIf
    Next nPos

    AAdd(aRet, AllTrim(cAtual))

Return aRet

/*/{Protheus.doc} U_SN1Campos
Extrai a lista de campos da estrutura.
@type function
/*/
Static Function U_SN1Campos(aEstr)
    Local aCampos := {}
    Local nI      := 0

    For nI := 1 To Len(aEstr)
        AAdd(aCampos, aEstr[nI, 1])
    Next nI

Return aCampos

/*/{Protheus.doc} U_SN1ConvCampo
Converte valor texto do CSV conforme tipo do campo destino.
@type function
/*/
Static Function U_SN1ConvCampo(cValor, cTipo)
    Local uRet := Nil
    Local cTmp := AllTrim(cValor)

    Do Case
    Case cTipo == "C" .Or. cTipo == "M"
        uRet := cTmp

    Case cTipo == "N"
        cTmp := StrTran(cTmp, ".", "")
        cTmp := StrTran(cTmp, ",", ".")
        uRet := Val(cTmp)

    Case cTipo == "D"
        cTmp := StrTran(cTmp, "-", "")
        cTmp := StrTran(cTmp, "/", "")
        If Len(cTmp) == 8
            uRet := StoD(cTmp)
        Else
            uRet := CtoD("")
        EndIf

    Case cTipo == "L"
        uRet := (Upper(Left(cTmp, 1)) $ "TSY1")

    Otherwise
        uRet := cTmp
    EndCase

Return uRet

/*/{Protheus.doc} U_SN1LogTxt
Monta o log em texto para exibicao em tela.
@type function
/*/
Static Function U_SN1LogTxt(aLog)
    Local cLog := ""
    Local nI   := 0

    For nI := 1 To Len(aLog)
        cLog += aLog[nI] + CRLF
    Next nI

Return cLog

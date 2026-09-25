Scriptname EXC:CyclerQuest extends Quest
{Explosives Cycler: списки гранат и мин из JSON, переключение списков и предметов по кругу, замена кончившегося предмета. Описание — PLAN.md.}

; Рабочие списки EXC_List01..10 и их объединение. Наполняются из JSON в LoadLists:
; FLST нужны для GetItemCount(список) одним вызовом и для фильтра событий инвентаря.
; Порядок предметов хранится отдельно, в Items (порядок script-added форм в FLST
; не гарантирован).
FormList[] Property EXC_Lists Auto Const Mandatory
FormList Property EXC_AllExplosives Auto Const Mandatory
Potion Property EXC_CycleItem Auto Const Mandatory

String Property MOD_NAME = "ExplosivesCycler" AutoReadOnly Hidden
String Property DATA_PATH = ".\\Data\\ExplosivesCycler\\" AutoReadOnly Hidden
String Property FILE_DEFAULT = "lists-default.json" AutoReadOnly Hidden
String Property FILE_USER = "lists-user.json" AutoReadOnly Hidden
String Property LOG_FILE = "ExplosivesCycler.log" AutoReadOnly Hidden
String Property LOG_FILE_PREV = "ExplosivesCycler.1.log" AutoReadOnly Hidden
Int Property MAX_LISTS = 10 AutoReadOnly Hidden
Int Property MAX_ITEMS = 128 AutoReadOnly Hidden
; Группы списков — клавиши MCM «Группа 1..3» (GroupKey1..3), поле "group" в JSON.
Int Property MAX_GROUPS = 3 AutoReadOnly Hidden
Int Property MAX_LOG_LINES = 100 AutoReadOnly Hidden
Int Property TIMER_REPLACE = 1 AutoReadOnly Hidden
String Property NAME_UNSET = "<unset>" AutoReadOnly Hidden
; Пауза между «кончился последний» и экипировкой следующего: EquipItem посреди
; анимации броска может её сорвать (проверка T3 в PLAN.md).
Float Property REPLACE_DELAY = 0.3 AutoReadOnly Hidden
Float Property BUSY_TIMEOUT = 10.0 AutoReadOnly Hidden

Int Property LOG_OFF = 0 AutoReadOnly Hidden
Int Property LOG_NORMAL = 1 AutoReadOnly Hidden
Int Property LOG_DEBUG = 2 AutoReadOnly Hidden

; --- строка на экране: Interface\ExplosivesCycler.swf (widget/EXCWidget.as) в HUDMenu ---
String Property HUD_MENU = "HUDMenu" AutoReadOnly Hidden
String Property WIDGET_SWF = "ExplosivesCycler.swf" AutoReadOnly Hidden
Int Property TIMER_HIDE = 2 AutoReadOnly Hidden
Int Property TIMER_ARMOR = 3 AutoReadOnly Hidden
; Сцена HUDMenu.swf — 1280x720 (заголовок SWF); положение в MCM — проценты от неё.
Float Property STAGE_W = 1280.0 AutoReadOnly Hidden
Float Property STAGE_H = 720.0 AutoReadOnly Hidden
; iDisplay: 0 ничего, 1 уведомления, 2 строка на экране, 3 строка и уведомления.
Int Property DISPLAY_NOTIFY = 1 AutoReadOnly Hidden
Int Property DISPLAY_LINE = 2 AutoReadOnly Hidden

; --- загруженные списки: плоский массив предметов + начало и длина каждого списка ---
Int ListCount = 0
String[] ListNames
Int[] ListStart
Int[] ListLen
; Группы списка — сумма 2^(группа-1): "group": "1,3" -> 5. 0 — ни в одной группе.
Int[] ListGroups
Form[] Items
; Кеш: язык, имя файла и строки файла, из которых собраны списки. Совпали — списки
; из сейва актуальны, разбор (сотни вызовов GOEPE) пропускается.
; ВНИМАНИЕ: хранить построчно, НЕ одной строкой. Строка длиннее ~4 КБ в переменной
; скрипта попадает в таблицу строк сейва, и загрузка такого сейва роняет игру
; (Buffout4: ReadableStringTable::ReadStringIntoBuffer; первая сборка, 2026-09-23).
String[] LoadedLines
String LoadedLang = ""
String LoadedFile = ""

; --- состояние ---
Int CurList = -1
Form CurItem = None
; Последние список и предмет в каждой группе (индекс = группа - 1): клавиша группы,
; нажатая из другой группы, возвращает к ним.
Int[] GroupLastList
Form[] GroupLastItem
Bool Busy = false
Float BusyStart = 0.0
String Lang = "en"

; --- настройки MCM (ReadSettings: при запуске, после изменения в MCM, при закрытии меню паузы) ---
Bool AutoNext = true
Bool EquipPickup = true
Bool ShowCount = true
Int LogLevel = 1
Int DisplayMode = 2
Float HideAfter = 0.0
Float PosX = 1.0
Float PosY = 95.5
Int Align = 0
Int FontSize = 22
Int ColorMode = 0

; --- виджет ---
String WidgetPath = ""          ; путь к клипу EXCWidget в HUDMenu, "" — не загружен
Bool WidgetLoading = false
String PendingText = ""         ; текст, пришедший до окончания загрузки виджета
String LastText = ""
Bool PreviewPending = false     ; в MCM меняли вид строки — показать её при выходе из меню
Bool StyleInPA = false          ; для какого HUD (обычный / силовая броня) выставлен цвет

String[] LogBuf
Bool LogDirty = false


; =====================================================================
;  Запуск и загрузка сейва
; =====================================================================

Event OnQuestInit()
    Setup(true)
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    Setup(false)
EndEvent

Function Setup(Bool abNewInstall)
    RotateLog()
    ReadSettings()
    Lang = ReadLanguage()
    Actor p = Game.GetPlayer()
    RegisterForRemoteEvent(p, "OnPlayerLoadGame")
    RegisterForRemoteEvent(p, "OnItemAdded")
    RegisterForRemoteEvent(p, "OnItemRemoved")
    RegisterForRemoteEvent(p, "OnItemEquipped")
    RegisterForRemoteEvent(p, "OnItemUnequipped")
    ; Без фильтра события инвентаря в Fallout 4 не приходят вовсе.
    RemoveAllInventoryEventFilters()
    AddInventoryEventFilter(EXC_AllExplosives)
    RegisterForExternalEvent("OnMCMSettingChange|" + MOD_NAME, "OnMCMSettingChange")
    RegisterForMenuOpenCloseEvent("PauseMenu")
    RegisterForMenuOpenCloseEvent(HUD_MENU)
    Log("=== Explosives Cycler: запуск (новая установка = " + abNewInstall + "), язык " + Lang)
    LoadLists(false)
    EnsureGroupMemory()
    If abNewInstall && p.GetItemCount(EXC_CycleItem) == 0
        p.AddItem(EXC_CycleItem, 1, true)
        Log("выдан предмет " + EXC_CycleItem.GetName())
    EndIf
    ; Сейв из другой сессии: клипа по сохранённому пути уже нет, EnsureWidget загрузит заново.
    WidgetPath = ""
    WidgetLoading = false
    If HideAfter <= 0.0 && CurItem != None && CurList >= 0
        ShowLine(Label(CurList, CurItem))
    EndIf
    FlushLog()
EndFunction

Function ReadSettings()
    If MCM.IsInstalled()
        AutoNext = MCM.GetModSettingBool(MOD_NAME, "bAutoNext:Main")
        EquipPickup = MCM.GetModSettingBool(MOD_NAME, "bEquipPickup:Main")
        ShowCount = MCM.GetModSettingBool(MOD_NAME, "bShowCount:Main")
        LogLevel = MCM.GetModSettingInt(MOD_NAME, "iLogLevel:Main")
        DisplayMode = MCM.GetModSettingInt(MOD_NAME, "iDisplay:Main")
        HideAfter = MCM.GetModSettingFloat(MOD_NAME, "fHideAfter:Main")
        PosX = MCM.GetModSettingFloat(MOD_NAME, "fPosX:Main")
        PosY = MCM.GetModSettingFloat(MOD_NAME, "fPosY:Main")
        Align = MCM.GetModSettingInt(MOD_NAME, "iAlign:Main")
        FontSize = MCM.GetModSettingInt(MOD_NAME, "iFontSize:Main")
        ColorMode = MCM.GetModSettingInt(MOD_NAME, "iColor:Main")
    EndIf
EndFunction

; MCM: внешнее событие «OnMCMSettingChange|ExplosivesCycler» (RegisterForExternalEvent, F4SE).
Function OnMCMSettingChange(String asModName, String asId)
    ReadSettings()
    If asId != "bAutoNext:Main" && asId != "bEquipPickup:Main" && asId != "iLogLevel:Main"
        PreviewPending = true
    EndIf
    Dbg("MCM: изменено " + asId)
EndFunction

; MCM живёт в меню паузы: при выходе из него применить вид строки и показать её,
; чтобы было видно, куда она встала. Настройки перечитываются и здесь — на случай,
; если внешнее событие MCM не пришло.
Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
    If asMenuName == "PauseMenu" && !abOpening
        String before = StyleKey()
        ReadSettings()
        If StyleKey() != before
            PreviewPending = true
        EndIf
        If PreviewPending
            PreviewPending = false
            If WidgetPath != ""
                ApplyStyle()
            EndIf
            If DisplayMode >= DISPLAY_LINE
                String text = LastText
                If CurItem != None && CurList >= 0
                    text = Label(CurList, CurItem)
                ElseIf text == ""
                    text = Tr("sample")
                EndIf
                ShowLine(text)
            Else
                HideLine()
            EndIf
            FlushLog()
        EndIf
    ElseIf asMenuName == HUD_MENU && abOpening
        ; HUD создан заново — старого клипа больше нет.
        WidgetPath = ""
        WidgetLoading = false
        If PendingText != ""
            EnsureWidget()
        EndIf
    EndIf
EndEvent

; Все настройки вида строки одной строкой — чтобы заметить, что их поменяли.
String Function StyleKey()
    Return DisplayMode + "|" + ShowCount + "|" + HideAfter + "|" + PosX + "|" + PosY + "|" + Align + "|" + FontSize + "|" + ColorMode
EndFunction

String Function ReadLanguage()
    String s = GardenOfEden.GetINISetting("sLanguage:General")
    If s == ""
        Return "en"
    EndIf
    Return GardenOfEden.ToLowerStr(s)
EndFunction


; =====================================================================
;  Команды: клавиши MCM (keybinds.json) и предмет мода.
;  НЕ ПЕРЕИМЕНОВЫВАТЬ: вызываются по имени из MCM.
; =====================================================================

Function NextList()
    Command(1, true)
EndFunction

Function PrevList()
    Command(-1, true)
EndFunction

Function NextItem()
    Command(1, false)
EndFunction

Function PrevItem()
    Command(-1, false)
EndFunction

Function GroupKey1()
    GroupCommand(1)
EndFunction

Function GroupKey2()
    GroupCommand(2)
EndFunction

Function GroupKey3()
    GroupCommand(3)
EndFunction

; Кнопка MCM «Перечитать списки».
Function McmReloadLists()
    If TryBusy()
        ReadSettings()
        Lang = ReadLanguage()
        Int n = LoadLists(true)
        ; Кнопка жмётся в MCM, где HUD не виден, — только уведомлением.
        Debug.Notification(Tr("loaded") + n + " (" + LoadedFile + ")")
        Busy = false
    EndIf
    FlushLog()
EndFunction

; Кнопка MCM «Выдать предмет».
Function McmGiveItem()
    Actor p = Game.GetPlayer()
    If p.GetItemCount(EXC_CycleItem) == 0
        p.AddItem(EXC_CycleItem, 1, false)
    EndIf
EndFunction

Function Command(Int aiDir, Bool abList)
    If !TryBusy()
        Return
    EndIf
    If ListCount == 0
        Say(Tr("nolists"))
    ElseIf abList || CurList < 0
        StepList(aiDir)
    Else
        StepItem(aiDir)
    EndIf
    Busy = false
    FlushLog()
EndFunction

Function GroupCommand(Int aiGroup)
    If !TryBusy()
        Return
    EndIf
    If ListCount == 0
        Say(Tr("nolists"))
    Else
        StepGroup(aiGroup)
    EndIf
    Busy = false
    FlushLog()
EndFunction

; Клавиша группы. Текущий список в этой группе — следующий непустой список группы по
; кругу, в нём первый имеющийся предмет. Текущий список из другой группы (или его нет) —
; последние список и предмет, выбранные в этой группе; их нет или они кончились —
; первый непустой список группы.
Function StepGroup(Int aiGroup)
    Actor p = Game.GetPlayer()
    EnsureGroupMemory()
    Int g = aiGroup - 1
    If FirstInGroup(aiGroup, -1, false) < 0
        Log("группа " + aiGroup + ": ни один список в неё не входит")
        Say(Tr("group") + " " + aiGroup + ": " + Tr("group_nolists"))
        Return
    EndIf
    String why = "группа " + aiGroup
    If CurList >= 0 && InGroup(CurList, aiGroup)
        Int next = FirstInGroup(aiGroup, CurList, true)
        If next >= 0
            EquipAt(next, FindAvailable(next, -1, 1), why + ", следующий список")
            Return
        EndIf
    Else
        Int last = GroupLastList[g]
        If last >= 0 && last < ListCount && InGroup(last, aiGroup) && p.GetItemCount(EXC_Lists[last]) > 0
            Form item = GroupLastItem[g]
            Int pos = FindItemPos(last, item)
            If pos < 0 || p.GetItemCount(item) == 0
                ; Запомненного предмета больше нет — следующий за ним имеющийся.
                pos = FindAvailable(last, pos, 1)
            EndIf
            EquipAt(last, pos, why + ", возврат к последнему")
            Return
        EndIf
        Int first = FirstInGroup(aiGroup, -1, true)
        If first >= 0
            EquipAt(first, FindAvailable(first, -1, 1), why + ", первый непустой")
            Return
        EndIf
    EndIf
    Log(why + ": во всех списках группы ничего нет")
    Say(GroupEmptyText(aiGroup))
EndFunction

; Первый по кругу после aiAfter список группы (aiAfter = -1 — с начала); abNonEmpty —
; только с чем-то в инвентаре. Сам aiAfter проверяется последним. Нет — -1.
Int Function FirstInGroup(Int aiGroup, Int aiAfter, Bool abNonEmpty)
    Actor p = Game.GetPlayer()
    Int k = 1
    While k <= ListCount
        Int idx = Wrap(aiAfter + k, ListCount)
        If InGroup(idx, aiGroup) && (!abNonEmpty || p.GetItemCount(EXC_Lists[idx]) > 0)
            Return idx
        EndIf
        k += 1
    EndWhile
    Return -1
EndFunction

; Входит ли список в группу: бит 2^(группа-1) в ListGroups (побитовых операций в Papyrus нет).
Bool Function InGroup(Int aiList, Int aiGroup)
    If ListGroups == None || aiList < 0 || aiList >= ListGroups.Length
        Return false
    EndIf
    Return (ListGroups[aiList] / GroupBit(aiGroup)) % 2 == 1
EndFunction

Int Function GroupBit(Int aiGroup)
    Int bit = 1
    Int i = 1
    While i < aiGroup
        bit *= 2
        i += 1
    EndWhile
    Return bit
EndFunction

; Сейвы до групп (1.1.x): массивов памяти групп в них нет.
Function EnsureGroupMemory()
    If GroupLastList == None || GroupLastList.Length != MAX_GROUPS || GroupLastItem == None || GroupLastItem.Length != MAX_GROUPS
        ResetGroupMemory()
    EndIf
EndFunction

Function ResetGroupMemory()
    GroupLastList = new Int[3]
    GroupLastItem = new Form[3]
    Int g = 0
    While g < MAX_GROUPS
        GroupLastList[g] = -1
        g += 1
    EndWhile
EndFunction

; Текущий список и предмет — последние во всех группах, куда входит список.
Function RememberGroups()
    If CurList < 0 || CurItem == None
        Return
    EndIf
    EnsureGroupMemory()
    Int g = 1
    While g <= MAX_GROUPS
        If InGroup(CurList, g)
            GroupLastList[g - 1] = CurList
            GroupLastItem[g - 1] = CurItem
        EndIf
        g += 1
    EndWhile
EndFunction

; Следующий (aiDir = 1) или предыдущий (-1) список, в котором что-то есть;
; в нём — первый имеющийся предмет.
Function StepList(Int aiDir)
    Actor p = Game.GetPlayer()
    Int base = CurList
    If base < 0
        If aiDir > 0
            base = -1
        Else
            base = 0
        EndIf
    EndIf
    Int found = -1
    Int k = 1
    While k <= ListCount && found < 0
        Int idx = Wrap(base + aiDir * k, ListCount)
        If p.GetItemCount(EXC_Lists[idx]) > 0
            found = idx
        EndIf
        k += 1
    EndWhile
    If found < 0
        Log("список " + aiDir + ": ни в одном списке ничего нет")
        Say(Tr("none"))
        Return
    EndIf
    CurList = found
    EquipAt(found, FindAvailable(found, -1, 1), "список " + aiDir)
EndFunction

; Следующий / предыдущий имеющийся предмет текущего списка, по кругу.
Function StepItem(Int aiDir)
    Actor p = Game.GetPlayer()
    If p.GetItemCount(EXC_Lists[CurList]) == 0
        Log("предмет " + aiDir + ": в списке " + ListTag(CurList) + " ничего нет")
        Say(EmptyText(CurList, None))
        Return
    EndIf
    Int pos = FindItemPos(CurList, CurItem)
    If pos < 0 && aiDir < 0
        pos = ListLen[CurList]
    EndIf
    EquipAt(CurList, FindAvailable(CurList, pos, aiDir), "предмет " + aiDir)
EndFunction

; Экипировать предмет aiPos списка aiList и показать «Метка Предмет ×N».
; Сначала текст, потом EquipItem: строка на экране меняется без ожидания экипировки.
Function EquipAt(Int aiList, Int aiPos, String asWhy)
    If aiPos < 0
        Return
    EndIf
    Form item = Items[ListStart[aiList] + aiPos]
    ; CurItem ставится ДО EquipItem: иначе OnItemUnequipped старого предмета
    ; (его ещё много) примет нашу же смену за ручную и сбросит отслеживание.
    CurItem = item
    CurList = aiList
    RememberGroups()
    String text = Label(aiList, item)
    Say(text)
    Actor p = Game.GetPlayer()
    p.EquipItem(item, false, true)
    If LogLevel >= LOG_NORMAL
        Log(asWhy + ": " + ListTag(aiList) + " -> " + text + " (" + p.GetItemCount(item) + " шт.)")
    EndIf
EndFunction


; =====================================================================
;  События инвентаря игрока (фильтр — EXC_AllExplosives)
; =====================================================================

Event ObjectReference.OnItemRemoved(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If CurItem != None && akBaseItem == CurItem
        Int left = Game.GetPlayer().GetItemCount(akBaseItem)
        Dbg("OnItemRemoved " + NameOf(akBaseItem) + " x" + aiItemCount + ", осталось " + left + ", куда " + akDestContainer)
        If left == 0
            ScheduleReplace()
        Else
            RefreshCount()
        EndIf
    EndIf
EndEvent

Event Actor.OnItemUnequipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
    WatchArmor(akBaseObject)
    If CurItem != None && akBaseObject == CurItem
        Int left = akSender.GetItemCount(akBaseObject)
        Dbg("OnItemUnequipped " + NameOf(akBaseObject) + ", осталось " + left)
        If left == 0
            ; Последний брошен. OnItemRemoved обычно приходит тоже — таймер один.
            ScheduleReplace()
        Else
            ; Игрок сам снял предмет или взял другой не из списков — не вмешиваемся.
            CurItem = None
        EndIf
    EndIf
EndEvent

; Вход в силовую броню / выход из неё надевает / снимает её части — через секунду
; после последней проверить, не пора ли сменить цвет строки (CheckArmorColor).
Function WatchArmor(Form akBaseObject)
    If ColorMode == 0 && WidgetPath != "" && (akBaseObject as Armor) != None
        StartTimer(1.0, TIMER_ARMOR)
    EndIf
EndFunction

Event Actor.OnItemEquipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
    WatchArmor(akBaseObject)
    If !EXC_AllExplosives.HasForm(akBaseObject)
        Return
    EndIf
    Bool changed = akBaseObject != CurItem
    CurItem = akBaseObject
    If CurList < 0 || !EXC_Lists[CurList].HasForm(akBaseObject)
        CurList = ListOf(akBaseObject)
    EndIf
    RememberGroups()
    ; Строка без таймера всегда показывает текущий предмет — и когда игрок взял его сам.
    If changed && HideAfter <= 0.0 && DisplayMode >= DISPLAY_LINE && CurList >= 0
        ShowLine(Label(CurList, akBaseObject))
    EndIf
    If LogLevel >= LOG_DEBUG
        ; Проверка T5: каким индексом GetEquippedWeapon отдаёт гранату.
        Dbg("OnItemEquipped " + NameOf(akBaseObject) + ", список " + CurList + ", IsEquipped=" + akSender.IsEquipped(akBaseObject) + \
            ", GetEquippedWeapon 0/1/2/3 = " + akSender.GetEquippedWeapon(0) + " / " + akSender.GetEquippedWeapon(1) + " / " + \
            akSender.GetEquippedWeapon(2) + " / " + akSender.GetEquippedWeapon(3))
        FlushLog()
    EndIf
EndEvent

; Подобран предмет текущего списка, а в руке для броска ничего нет — экипировать.
Event ObjectReference.OnItemAdded(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    ; Добавился текущий и он в руке — только обновить число. Если он кончился и был
    ; снят (замена выключена), дальше обычная логика «подобранное экипировать».
    If CurItem != None && akBaseItem == CurItem && ThrowableEquipped()
        RefreshCount()
        Return
    EndIf
    If CurList < 0 || !EXC_Lists[CurList].HasForm(akBaseItem)
        Return
    EndIf
    If !EquipPickup || ThrowableEquipped()
        Return
    EndIf
    If TryBusy(false)
        EquipAt(CurList, FindItemPos(CurList, akBaseItem), "подобран")
        Busy = false
        FlushLog()
    EndIf
EndEvent

Function ScheduleReplace()
    If AutoNext
        StartTimer(REPLACE_DELAY, TIMER_REPLACE)
    EndIf
EndFunction

Event OnTimer(int aiTimerID)
    If aiTimerID == TIMER_REPLACE
        ReplaceRanOut()
    ElseIf aiTimerID == TIMER_HIDE
        If WidgetPath != ""
            UI.Set(HUD_MENU, WidgetPath + ".visible", false)
        EndIf
    ElseIf aiTimerID == TIMER_ARMOR
        CheckArmorColor()
    EndIf
EndEvent

; Текущий предмет кончился: следующий имеющийся в том же списке, по кругу.
; Список пуст — сообщение и остановка (на другой список не переходим).
Function ReplaceRanOut()
    If CurItem == None || CurList < 0
        Return
    EndIf
    If Game.GetPlayer().GetItemCount(CurItem) > 0
        Return
    EndIf
    If !TryBusy(false)
        ; Идёт команда с клавиши — она сама экипирует нужное.
        Return
    EndIf
    Int pos = FindAvailable(CurList, FindItemPos(CurList, CurItem), 1)
    If pos < 0
        Log("кончился " + NameOf(CurItem) + ", в списке " + ListTag(CurList) + " больше ничего нет")
        Say(EmptyText(CurList, CurItem))
        CurItem = None
    Else
        EquipAt(CurList, pos, "кончился " + NameOf(CurItem))
    EndIf
    Busy = false
    FlushLog()
EndFunction

; Экипирован ли сейчас бросаемый предмет. Видим только отслеживаемый CurItem:
; гранату не из списков, взятую до запуска мода, скрипт не знает.
Bool Function ThrowableEquipped()
    If CurItem == None
        Return false
    EndIf
    Actor p = Game.GetPlayer()
    Return p.GetItemCount(CurItem) > 0 && p.IsEquipped(CurItem)
EndFunction


; =====================================================================
;  Поиск в списках
; =====================================================================

Int Function Wrap(Int aiValue, Int aiCount)
    Int r = aiValue % aiCount
    If r < 0
        r += aiCount
    EndIf
    Return r
EndFunction

; Позиция предмета в списке или -1.
Int Function FindItemPos(Int aiList, Form akItem)
    If akItem == None || aiList < 0
        Return -1
    EndIf
    Int start = ListStart[aiList]
    Int i = 0
    While i < ListLen[aiList]
        If Items[start + i] == akItem
            Return i
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

; Первый список, где есть предмет, или -1.
Int Function ListOf(Form akItem)
    Int i = 0
    While i < ListCount
        If FindItemPos(i, akItem) >= 0
            Return i
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

; Ближайшая по кругу позиция с предметом в инвентаре, начиная с aiPos + aiDir.
; aiPos = -1 при aiDir = 1 — поиск с начала списка. Сама aiPos проверяется последней.
Int Function FindAvailable(Int aiList, Int aiPos, Int aiDir)
    Int len = ListLen[aiList]
    If len <= 0
        Return -1
    EndIf
    Actor p = Game.GetPlayer()
    Int start = ListStart[aiList]
    Int k = 1
    While k <= len
        Int pos = Wrap(aiPos + aiDir * k, len)
        If p.GetItemCount(Items[start + pos]) > 0
            Return pos
        EndIf
        k += 1
    EndWhile
    Return -1
EndFunction


; =====================================================================
;  Загрузка списков из JSON
; =====================================================================
;
; lists-user.json, если он есть, полностью заменяет lists-default.json.
; Разбор построчный, без JSON-парсера (формат описан в самом файле и в PLAN.md §3):
; у каждой строки берётся текст в последних кавычках (GOEPE ExtractLastQuotedText):
;   "items"            — открывает новый список, названия до него — его названия;
;   "Плагин.esm|ID"    — предмет последнего открытого списка;
;   "name_en"/"name_<язык>": значение — название.
; Строки с _comment пропускаются. GOEPE StrFind возвращает ЧИСЛО вхождений, не позицию.
Int Function LoadLists(Bool abForce)
    String file = FILE_DEFAULT
    If GardenOfEden2.DoesFileExist(FILE_USER, DATA_PATH)
        file = FILE_USER
    ElseIf !GardenOfEden2.DoesFileExist(FILE_DEFAULT, DATA_PATH)
        Log("ОШИБКА: нет ни " + FILE_USER + ", ни " + FILE_DEFAULT + " в " + DATA_PATH)
        ClearLists()
        LoadedLines = None
        LoadedFile = ""
        Return 0
    EndIf
    String[] lines = GardenOfEden2.GetLinesFromFile(file, DATA_PATH)
    ; ListGroups == None — сейв до групп: разобрать заново, даже если файл тот же.
    If !abForce && ListCount > 0 && ListGroups != None && ListGroups.Length == ListCount && SameAsLoaded(lines, file)
        Log("списки не изменились (" + file + "): " + ListCount + " шт., " + Items.Length + " предметов")
        Return ListCount
    EndIf

    Float t0 = Utility.GetCurrentRealTime()
    ClearLists()
    Int i = 0
    ; NAME_UNSET, а не "": пустое название в файле — законное («только имя предмета»).
    String nameEn = NAME_UNSET
    String nameLang = NAME_UNSET
    Int groups = 0
    String keyLang = "\"name_" + Lang + "\""
    Int cur = -1
    Int extraLists = 0
    Int missing = 0
    Int broken = 0
    i = 0
    While i < lines.Length
        String line = lines[i]
        String q = GardenOfEden.ExtractLastQuotedText(line)
        If q == "lists"
            ; заголовок массива списков
        ElseIf q == ""
            ; скобки и пустые строки — или пустое название: "name_ru": ""
            If GardenOfEden.StrFind(line, "\"name_en\"") > 0
                nameEn = ""
            ElseIf GardenOfEden.StrFind(line, keyLang) > 0
                nameLang = ""
            EndIf
        ElseIf q == "items"
            If ListCount < MAX_LISTS
                cur = ListCount
                ListCount += 1
                ListNames.Add(PickName(nameEn, nameLang, cur))
                ListStart.Add(Items.Length)
                ListLen.Add(0)
                ListGroups.Add(groups)
            Else
                cur = -1
                extraLists += 1
            EndIf
            nameEn = NAME_UNSET
            nameLang = NAME_UNSET
            groups = 0
        ElseIf GardenOfEden.StrFind(line, "_comment") > 0
            ; комментарий
        ElseIf GardenOfEden.StrFind(line, "\"group\"") > 0
            groups = ParseGroups(line, i + 1)
        ElseIf GardenOfEden.StrFind(q, "|") > 0
            If cur >= 0
                Int r = AddListItem(cur, q, i + 1)
                If r == 1
                    missing += 1
                ElseIf r == 2
                    broken += 1
                EndIf
            EndIf
        ElseIf GardenOfEden.StrFind(line, "\"name_en\"") > 0
            nameEn = NameValue(q, "name_en")
        ElseIf GardenOfEden.StrFind(line, keyLang) > 0
            nameLang = NameValue(q, "name_" + Lang)
        EndIf
        i += 1
    EndWhile
    LoadedLines = lines
    LoadedLang = Lang
    LoadedFile = file

    ; Текущий предмет мог уйти в другой список или пропасть из списков совсем.
    CurList = ListOf(CurItem)
    If CurList < 0
        CurItem = None
    EndIf
    ; Номера списков могли смениться — память групп начинается заново.
    ResetGroupMemory()
    RememberGroups()

    Log("списки загружены из " + file + " за " + ((Utility.GetCurrentRealTime() - t0) as Int) + " с: " + ListCount + " шт., " + \
        Items.Length + " предметов; нет плагина " + missing + ", ошибок " + broken + ", лишних списков " + extraLists)
    i = 0
    While i < ListCount
        Log("  " + ListTag(i) + ": " + ListLen[i] + " предм., группы " + GroupsText(i))
        i += 1
    EndWhile
    Return ListCount
EndFunction

; "group": "1,3" (или "group": 2) — цифры строки 1..MAX_GROUPS. В ключе цифр нет,
; поэтому смотрится вся строка; запятые, пробелы и кавычки пропускаются.
Int Function ParseGroups(String asLine, Int aiLine)
    Int mask = 0
    Int n = GardenOfEden.StrLength(asLine)
    Int i = 0
    While i < n
        String c = GardenOfEden.SubStr(asLine, i, 1)
        Int d = 0
        If c == "1"
            d = 1
        ElseIf c == "2"
            d = 2
        ElseIf c == "3"
            d = 3
        ElseIf c == "0" || c == "4" || c == "5" || c == "6" || c == "7" || c == "8" || c == "9"
            Log("  строка " + aiLine + ": группа " + c + " — есть только 1.." + MAX_GROUPS + ", пропущена")
        EndIf
        If d > 0 && (mask / GroupBit(d)) % 2 == 0
            mask += GroupBit(d)
        EndIf
        i += 1
    EndWhile
    Return mask
EndFunction

; Для лога: «1,3», без групп — «-».
String Function GroupsText(Int aiList)
    String s = ""
    Int g = 1
    While g <= MAX_GROUPS
        If InGroup(aiList, g)
            If s != ""
                s += ","
            EndIf
            s += g
        EndIf
        g += 1
    EndWhile
    If s == ""
        Return "-"
    EndIf
    Return s
EndFunction

Bool Function SameAsLoaded(String[] akLines, String asFile)
    If LoadedLines == None || akLines == None || LoadedLines.Length != akLines.Length
        Return false
    EndIf
    If LoadedLang != Lang || LoadedFile != asFile
        Return false
    EndIf
    Int i = 0
    While i < akLines.Length
        If LoadedLines[i] != akLines[i]
            Return false
        EndIf
        i += 1
    EndWhile
    Return true
EndFunction

; Значение названия. Если ExtractLastQuotedText вернула сам ключ (значение без
; кавычек или пустое), название считается пустым.
String Function NameValue(String asQuoted, String asKey)
    If asQuoted == asKey
        Return ""
    EndIf
    Return asQuoted
EndFunction

String Function PickName(String asEn, String asLang, Int aiIndex)
    If asLang != NAME_UNSET
        Return asLang
    ElseIf asEn != NAME_UNSET
        Return asEn
    EndIf
    Return Tr("list") + " " + (aiIndex + 1)
EndFunction

; Для лога: «2 ([grenade])».
String Function ListTag(Int aiList)
    Return (aiList + 1) + " (" + ListNames[aiList] + ")"
EndFunction

; Текст: «Название списка Предмет», при пустом названии — «Предмет». С количеством
; (MCM «Показывать количество»): «[grenade] Осколочная граната ×8» — метки значков
; в названии виджет рисует значками, уведомлениям их убирает PlainText.
String Function Label(Int aiList, Form akItem, Bool abCount = true)
    String text = NameOf(akItem)
    If abCount && ShowCount
        text += " ×" + Game.GetPlayer().GetItemCount(akItem)
    EndIf
    String name = ListNames[aiList]
    If name == ""
        Return text
    EndIf
    Return name + " " + text
EndFunction

; Число в строке после броска / подбора текущего предмета. Только в строку:
; уведомление на каждый бросок было бы лишним.
Function RefreshCount()
    If ShowCount && DisplayMode >= DISPLAY_LINE && CurItem != None && CurList >= 0
        ShowLine(Label(CurList, CurItem))
    EndIf
EndFunction

; Список опустел: «[grenade] Предмет: список пуст», без предмета — «[grenade] Список 1 пуст».
String Function EmptyText(Int aiList, Form akItem)
    If akItem != None
        Return Label(aiList, akItem, false) + ": " + Tr("list_empty")
    EndIf
    String text = Tr("list") + " " + (aiList + 1) + " " + Tr("empty")
    If ListNames[aiList] != ""
        text = ListNames[aiList] + " " + text
    EndIf
    Return text
EndFunction

; Во всех списках группы пусто: «[grenade] Группа 1: ничего нет» — значки первого списка группы.
String Function GroupEmptyText(Int aiGroup)
    String text = Tr("group") + " " + aiGroup + ": " + Tr("group_none")
    Int first = FirstInGroup(aiGroup, -1, false)
    If first >= 0 && ListNames[first] != ""
        text = ListNames[first] + " " + text
    EndIf
    Return text
EndFunction

; 0 — добавлен (или повтор), 1 — нет плагина (DLC), 2 — ошибка.
Int Function AddListItem(Int aiList, String asToken, Int aiLine)
    String[] parts = GardenOfEden2.GetCommaDelimitedStringAsArray(GardenOfEden.ReplaceStr(asToken, "|", ","))
    If parts == None || parts.Length != 2
        Log("  строка " + aiLine + ": не разобрано " + asToken)
        Return 2
    EndIf
    Int id = GardenOfEden2.HexFormIDToInt(parts[1])
    If id <= 0
        Log("  строка " + aiLine + ": плохой FormID " + asToken)
        Return 2
    EndIf
    Form f = Game.GetFormFromFile(id, parts[0])
    If f == None
        Dbg("  строка " + aiLine + ": нет формы " + asToken + " (плагин не установлен?)")
        Return 1
    EndIf
    If (f as Weapon) == None
        Log("  строка " + aiLine + ": " + asToken + " — не граната и не мина, пропущено")
        Return 2
    EndIf
    If EXC_Lists[aiList].HasForm(f)
        Return 0
    EndIf
    If Items.Length >= MAX_ITEMS
        Log("  строка " + aiLine + ": больше " + MAX_ITEMS + " предметов во всех списках, " + asToken + " пропущен")
        Return 2
    EndIf
    Items.Add(f)
    ListLen[aiList] = ListLen[aiList] + 1
    EXC_Lists[aiList].AddForm(f)
    If !EXC_AllExplosives.HasForm(f)
        EXC_AllExplosives.AddForm(f)
    EndIf
    Return 0
EndFunction

Function ClearLists()
    Int i = 0
    While i < EXC_Lists.Length
        EXC_Lists[i].Revert()
        i += 1
    EndWhile
    EXC_AllExplosives.Revert()
    ListCount = 0
    ListNames = new String[0]
    ListStart = new Int[0]
    ListLen = new Int[0]
    ListGroups = new Int[0]
    Items = new Form[0]
EndFunction


; =====================================================================
;  Сообщения, язык, лог
; =====================================================================

; Строки уведомлений: ru — если sLanguage = ru, иначе en.
String Function Tr(String asId)
    If Lang == "ru"
        If asId == "none"
            Return "Нет взрывчатки из списков"
        ElseIf asId == "empty"
            Return "пуст"
        ElseIf asId == "list_empty"
            Return "список пуст"
        ElseIf asId == "nolists"
            Return "Списки взрывчатки не загружены (см. ExplosivesCycler.log)"
        ElseIf asId == "loaded"
            Return "Explosives Cycler: списков загружено "
        ElseIf asId == "list"
            Return "Список"
        ElseIf asId == "sample"
            Return "[grenade] Осколочная граната"
        ElseIf asId == "group"
            Return "Группа"
        ElseIf asId == "group_none"
            Return "ничего нет"
        ElseIf asId == "group_nolists"
            Return "в неё не входит ни один список (\"group\" в lists-*.json)"
        EndIf
    EndIf
    If asId == "none"
        Return "No explosives from the lists"
    ElseIf asId == "empty"
        Return "is empty"
    ElseIf asId == "list_empty"
        Return "list is empty"
    ElseIf asId == "nolists"
        Return "Explosives lists are not loaded (see ExplosivesCycler.log)"
    ElseIf asId == "loaded"
        Return "Explosives Cycler: lists loaded "
    ElseIf asId == "list"
        Return "List"
    ElseIf asId == "sample"
        Return "[grenade] Fragmentation Grenade"
    ElseIf asId == "group"
        Return "Group"
    ElseIf asId == "group_none"
        Return "nothing left"
    ElseIf asId == "group_nolists"
        Return "no lists in it (\"group\" in lists-*.json)"
    EndIf
    Return asId
EndFunction

; Показать текст выбранным в MCM способом (iDisplay).
Function Say(String asText)
    If DisplayMode >= DISPLAY_LINE
        ShowLine(asText)
    EndIf
    If DisplayMode == DISPLAY_NOTIFY || DisplayMode == DISPLAY_LINE + DISPLAY_NOTIFY
        Debug.Notification(PlainText(asText))
    EndIf
EndFunction

; Уведомления игры значков не умеют: метки [grenade] / [mine] / [molotov] убираются
; вместе с пробелами в начале. GOEPE ReplaceStr различает регистр — метки в нижнем
; регистре (виджет понимает любой). StrFind тоже с учётом регистра, иначе на
; «[Grenade]» цикл не кончился бы; он возвращает число вхождений, не позицию.
String Function PlainText(String asText)
    String s = StripToken(asText, "[grenade]")
    s = StripToken(s, "[mine]")
    s = StripToken(s, "[molotov]")
    While GardenOfEden.SubStr(s, 0, 1) == " "
        s = GardenOfEden.SubStr(s, 1)
    EndWhile
    Return s
EndFunction

String Function StripToken(String asText, String asToken)
    String s = asText
    Int guard = 0
    While guard < 10 && GardenOfEden.StrFind(s, asToken, 0, true) > 0
        s = GardenOfEden.ReplaceStr(s, asToken, "")
        guard += 1
    EndWhile
    Return s
EndFunction


; =====================================================================
;  Строка на экране (виджет в HUDMenu)
; =====================================================================
;
; Уведомления Debug.Notification идут очередью, по одному, — при быстрых нажатиях
; видно не то, что выбрано сейчас. Поэтому свой клип: Interface\ExplosivesCycler.swf
; (класс EXCWidget, исходник widget/EXCWidget.as) грузится F4SE UI.Load в корень
; HUDMenu, текст меняется UI.Invoke(SetText) сразу. Загрузка асинхронная: текст,
; пришедший до неё, ждёт в PendingText.

Function ShowLine(String asText)
    LastText = asText
    If !EnsureWidget()
        PendingText = asText
        Return
    EndIf
    CheckArmorColor()
    Var[] args = new Var[1]
    args[0] = asText
    UI.Invoke(HUD_MENU, WidgetPath + ".SetText", args)
    UI.Set(HUD_MENU, WidgetPath + ".visible", true)
    If HideAfter > 0.0
        StartTimer(HideAfter, TIMER_HIDE)
    Else
        CancelTimer(TIMER_HIDE)
    EndIf
EndFunction

Function HideLine()
    CancelTimer(TIMER_HIDE)
    If WidgetPath != ""
        UI.Set(HUD_MENU, WidgetPath + ".visible", false)
    EndIf
EndFunction

; true — виджет готов (WidgetPath указывает на живой клип). Иначе запускает загрузку.
Bool Function EnsureWidget()
    If WidgetPath != ""
        If UI.Get(HUD_MENU, WidgetPath + ".ready") as Bool
            Return true
        EndIf
        Dbg("виджет пропал (" + WidgetPath + "), загружаю заново")
        WidgetPath = ""
    EndIf
    If WidgetLoading || !UI.IsMenuOpen(HUD_MENU)
        Return false
    EndIf
    WidgetLoading = true
    If !UI.Load(HUD_MENU, "root1", WIDGET_SWF, Self, "OnWidgetLoaded")
        WidgetLoading = false
        Log("ОШИБКА: UI.Load не запустился (" + WIDGET_SWF + ")")
    EndIf
    Return false
EndFunction

; Колбэк UI.Load. НЕ ПЕРЕИМЕНОВЫВАТЬ: имя передаётся в UI.Load строкой.
Function OnWidgetLoaded(Bool abSuccess, String asMenuName, String asSourceVar, String asDestVar, String asAssetPath)
    WidgetLoading = false
    If !abSuccess
        Log("ОШИБКА: виджет не загрузился: " + asAssetPath + " -> " + asDestVar)
        FlushLog()
        Return
    EndIf
    ; destVar — либо сам клип, либо Loader; EXCWidget узнаём по полю ready = true.
    If UI.Get(HUD_MENU, asDestVar + ".ready") as Bool
        WidgetPath = asDestVar
    ElseIf UI.Get(HUD_MENU, asDestVar + ".content.ready") as Bool
        WidgetPath = asDestVar + ".content"
    Else
        Log("ОШИБКА: в " + asDestVar + " нет клипа EXCWidget")
        FlushLog()
        Return
    EndIf
    Log("виджет загружен: " + WidgetPath)
    ApplyStyle()
    If PendingText != ""
        String text = PendingText
        PendingText = ""
        ShowLine(text)
    Else
        UI.Set(HUD_MENU, WidgetPath + ".visible", false)
    EndIf
    FlushLog()
EndFunction

; Положение (проценты сцены 1280x720), кегль, цвет, выравнивание.
Function ApplyStyle()
    StyleInPA = Game.GetPlayer().IsInPowerArmor()
    Int color = LineColor(StyleInPA)
    Dbg("вид строки: X " + PosX + "%, Y " + PosY + "%, шрифт " + FontSize + ", цвет " + GardenOfEden.IntToHex(color) + \
        ", силовая броня " + StyleInPA)
    Var[] args = new Var[3]
    args[0] = FontSize
    args[1] = color
    args[2] = Align
    UI.Invoke(HUD_MENU, WidgetPath + ".SetStyle", args)
    UI.Set(HUD_MENU, WidgetPath + ".x", STAGE_W * PosX / 100.0)
    UI.Set(HUD_MENU, WidgetPath + ".y", STAGE_H * PosY / 100.0)
EndFunction

; iColor: 0 — цвет HUD из настроек игры, дальше — готовые.
; Цвет HUD у игры ДВА (Fallout4Prefs.ini): обычный — iHUDColorR/G/B:Interface (0..255),
; в силовой броне — fPAEffectColorR/G/B (0..1; в ini его может не быть, тогда
; GetINISetting отдаёт значение по умолчанию). fPipboyEffectColor* — цвет Pip-Boy, не HUD
; (первая версия брала его, и в броне цвет не совпадал).
Int Function LineColor(Bool abInPA)
    If ColorMode == 1
        Return 0xFFFFFF
    ElseIf ColorMode == 2
        Return 0xFFB642
    ElseIf ColorMode == 3
        Return 0x5AC8FF
    ElseIf ColorMode == 4
        Return 0xFF5A4A
    EndIf
    If abInPA
        Int r = UnitColorByte(IniValue("fPAEffectColorR"), 255)
        Int g = UnitColorByte(IniValue("fPAEffectColorG"), 209)
        Int b = UnitColorByte(IniValue("fPAEffectColorB"), 105)
        Return r * 65536 + g * 256 + b
    EndIf
    Int r = ByteColor(GardenOfEden.GetINISetting("iHUDColorR:Interface"), 18)
    Int g = ByteColor(GardenOfEden.GetINISetting("iHUDColorG:Interface"), 255)
    Int b = ByteColor(GardenOfEden.GetINISetting("iHUDColorB:Interface"), 21)
    Return r * 65536 + g * 256 + b
EndFunction

; Секция fPAEffectColor* не известна наверняка — пробуем обе, где лежат соседние цвета.
String Function IniValue(String asName)
    String v = GardenOfEden.GetINISetting(asName + ":Pipboy")
    If v == ""
        v = GardenOfEden.GetINISetting(asName + ":Interface")
    EndIf
    Return v
EndFunction

; "0.82" -> 209
Int Function UnitColorByte(String asValue, Int aiDefault)
    If asValue == ""
        Return aiDefault
    EndIf
    Return Clamp255(((asValue as Float) * 255.0 + 0.5) as Int)
EndFunction

; "255" -> 255
Int Function ByteColor(String asValue, Int aiDefault)
    If asValue == ""
        Return aiDefault
    EndIf
    Return Clamp255(asValue as Int)
EndFunction

Int Function Clamp255(Int aiValue)
    If aiValue < 0
        Return 0
    ElseIf aiValue > 255
        Return 255
    EndIf
    Return aiValue
EndFunction

; Вход в силовую броню / выход: перекрасить строку, если цвет — «цвет HUD».
; Зовётся таймером после надевания/снятия брони (OnItemEquipped/Unequipped) и из ShowLine.
Function CheckArmorColor()
    If ColorMode == 0 && WidgetPath != "" && Game.GetPlayer().IsInPowerArmor() != StyleInPA
        ApplyStyle()
    EndIf
EndFunction

; F4SE Form.GetName(): имя из игры, на языке игры.
String Function NameOf(Form akItem)
    If akItem == None
        Return "None"
    EndIf
    String n = akItem.GetName()
    If n == ""
        Return akItem as String
    EndIf
    Return n
EndFunction

; Занять мод на время команды. Занятость дольше BUSY_TIMEOUT считается брошенной
; (стек потерян при загрузке сейва).
Bool Function TryBusy(Bool abLoud = true)
    Float now = Utility.GetCurrentRealTime()
    If Busy && now >= BusyStart && now - BusyStart < BUSY_TIMEOUT
        Return false
    EndIf
    Busy = true
    BusyStart = now
    Return true
EndFunction

Function Log(String asText)
    If LogLevel >= LOG_NORMAL
        AddLogLine(asText)
    EndIf
EndFunction

Function Dbg(String asText)
    If LogLevel >= LOG_DEBUG
        AddLogLine(asText)
    EndIf
EndFunction

Function AddLogLine(String asText)
    If LogBuf == None
        LogBuf = new String[0]
    EndIf
    If LogBuf.Length >= MAX_LOG_LINES
        LogBuf.Remove(0)
    EndIf
    LogBuf.Add(GardenOfEden2.GetCurrentDateAndTimeAsString() + "  " + asText)
    LogDirty = true
EndFunction

; Лог пишется целиком (последние MAX_LOG_LINES строк сессии): WriteLinesToFile
; не умеет дописывать в существующий файл.
Function FlushLog()
    If LogDirty && LogBuf != None && LogLevel > LOG_OFF
        GardenOfEden3.WriteLinesToFile(LOG_FILE, DATA_PATH, LogBuf, true)
    EndIf
    LogDirty = false
EndFunction

; Прошлая сессия -> ExplosivesCycler.1.log, новая начинается с пустого буфера.
Function RotateLog()
    If GardenOfEden2.DoesFileExist(LOG_FILE, DATA_PATH)
        String[] old = GardenOfEden2.GetLinesFromFile(LOG_FILE, DATA_PATH)
        If old != None && old.Length > 0
            GardenOfEden3.WriteLinesToFile(LOG_FILE_PREV, DATA_PATH, old, true)
        EndIf
    EndIf
    LogBuf = new String[0]
    LogDirty = false
EndFunction

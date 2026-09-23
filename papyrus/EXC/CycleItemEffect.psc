Scriptname EXC:CycleItemEffect extends ActiveMagicEffect
{Эффект предмета «Explosives Cycler»: следующий список взрывчатки, как клавиша MCM. Предмет возвращается в инвентарь.}

EXC:CyclerQuest Property Cycler Auto Const Mandatory
Potion Property SelfItem Auto Const Mandatory

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akTarget == Game.GetPlayer()
        akTarget.AddItem(SelfItem, 1, true)
        Cycler.NextList()
    EndIf
EndEvent

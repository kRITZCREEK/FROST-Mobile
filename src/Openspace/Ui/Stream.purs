module Openspace.Ui.Stream where

import Control.Monad.Eff
import Control.Monad.ST
import DOM
import Data.Either
import Data.Foreign
import Openspace.Engine
import Openspace.Network.Socket
import Openspace.Types
import Openspace.Ui.Emitter
import Openspace.Ui.Parser
import Openspace.Ui.Render
import Rx.Observable

netStream :: forall eff. Socket -> Eff( net :: Net | eff ) (Observable Action)
netStream socket = do
  onReceive <- socketObserver socket
  return $ actionFromForeign parseAction id <$> (parseMessage <$> onReceive)

dragStream :: forall eff. Eff( dom :: DOM| eff) (Observable Action)
dragStream = do
  emitters <- getEmitters
  let lookup = emitterLookup emitters
      dragOverSlot = (\e -> case parseSlot (getDetail e) of
                         Right s -> AssignTopic s
                         Left e -> UnassignTopic
                     ) <$> lookup "dragOverSlot"

      dragOverTrash = const DeleteTopic <$> lookup "dragOverTrash"

      -- HTML 5 fires dragLeave before dragEnd occurs
      -- TODO: Find a cleaner solution
      dragLeave = delay 30 $ const UnassignTopic
                  <$> lookup "dragLeaveSlot" `merge` lookup "dragLeaveTrash"

      dragOver = dragLeave `merge` dragOverSlot `merge` dragOverTrash

      dragStart = parseTopic <<< getDetail
                  <$> lookup "dragStartTopic" `merge` lookup "dragStartGridTopic"

      dragTopic = do Right t <- dragStart
                     action <- dragOver
                     lookup "dragEndTopic" `merge` lookup "dragEndGridTopic"
                     return $ action t
  return dragTopic

uiStream :: forall eff. Eff( dom :: DOM | eff ) (Observable Action)
uiStream = do
  emitters <- getEmitters
  let lookup = emitterLookup emitters
      addTopic    = (actionFromForeign parseTopic AddTopic) <<< getDetail
                    <$> lookup "addTopic"
      addRoom     = (actionFromForeign parseRoom AddRoom) <<< getDetail
                    <$> lookup "addRoom"
      deleteRoom  = (actionFromForeign parseRoom DeleteRoom) <<< getDetail
                    <$> lookup "deleteRoom"
      addBlock    = (actionFromForeign parseBlock AddBlock) <<< getDetail
                    <$> lookup "addBlock"
      deleteBlock = (actionFromForeign parseBlock DeleteBlock) <<< getDetail
                    <$> lookup "deleteBlock"
      changeGrid = addRoom `merge` deleteRoom `merge` addBlock `merge` deleteBlock
  dragTopic <- dragStream
  return $ addTopic `merge` dragTopic `merge` changeGrid

main = do
  -- TODO: getSocket :: Either SockErr Socket
  let sockEmitter = getSocket "ws://192.168.5.113/socket"
  -- until Websocket support is given by the server
  -- let sockEmitter = EmptySocket
  -- Initial State
  appSt <- newSTRef myState1
  -- Initial Render
  readSTRef appSt >>= renderApp

  --Request Initial State
  emitRefresh sockEmitter

  -- Observable Action
  ui  <- uiStream
  net <- netStream sockEmitter
  -- Broadcast the UI Observable
  subscribe ui (\a -> emitAction sockEmitter (serialize a))
  -- Evaluate Action Observables
  let actions = net --ui `merge` net
  subscribe actions (\a -> modifySTRef appSt (evalAction a) >>= renderApp)

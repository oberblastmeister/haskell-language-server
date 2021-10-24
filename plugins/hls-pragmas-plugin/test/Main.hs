{-# LANGUAGE OverloadedStrings #-}
module Main
  ( main
  ) where

import           Control.Lens            ((^.))
import qualified Data.Text               as T
import qualified Ide.Plugin.Pragmas      as Pragmas
import qualified Language.LSP.Types.Lens as L
import           System.FilePath
import           Test.Hls

main :: IO ()
main = defaultTestRunner tests

pragmasPlugin :: PluginDescriptor IdeState
pragmasPlugin = Pragmas.descriptor "pragmas"

tests :: TestTree
tests =
  testGroup "pragmas"
  [ codeActionTests
  , codeActionTests'
  , completionTests
  ]

codeActionTests :: TestTree
codeActionTests =
  testGroup "code actions"
  [ codeActionTest "adds LANGUAGE with no other pragmas at start ignoring later INLINE pragma" "AddPragmaIgnoreInline" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE after shebang preceded by other LANGUAGE and GHC_OPTIONS" "AddPragmaAfterShebangPrecededByLangAndOptsGhc" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE after shebang with other Language preceding shebang" "AddPragmaAfterShebangPrecededByLangAndOptsGhc" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE before Doc comments after interchanging pragmas" "BeforeDocInterchanging" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "Add language after altering OPTIONS_GHC and Language" "AddLanguagePragmaAfterInterchaningOptsGhcAndLangs" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "Add language after pragmas with non standard space between prefix and name" "AddPragmaWithNonStandardSpacingInPrecedingPragmas" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE after OptGHC at start ignoring later INLINE pragma" "AddPragmaAfterOptsGhcIgnoreInline" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE ignore later Ann pragma" "AddPragmaIgnoreLaterAnnPragma" [("Add \"BangPatterns\"", "Contains BangPatterns code action")]
  , codeActionTest "adds LANGUAGE after interchanging pragmas ignoring later Ann pragma" "AddLanguageAfterInterchaningIgnoringLaterAnn" [("Add \"BangPatterns\"", "Contains BangPatterns code action")]
  , codeActionTest "adds LANGUAGE after OptGHC preceded by another language pragma" "AddLanguageAfterLanguageThenOptsGhc" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "adds LANGUAGE pragma after shebang and last language pragma" "AfterShebangAndPragma" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "adds above module keyword on first line" "ModuleOnFirstLine" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma after GHC_OPTIONS" "AfterGhcOptions" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma after shebang and GHC_OPTIONS" "AfterShebangAndOpts" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma after shebang, GHC_OPTIONS and language pragma" "AfterShebangAndOptionsAndPragma" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma after all others ignoring later INLINE pragma" "AfterShebangAndOptionsAndPragmasIgnoreInline" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma after all others ignoring multiple later INLINE pragma" "AfterAllWithMultipleInlines" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds LANGUAGE pragma correctly ignoring later INLINE pragma" "AddLanguagePragma" [("Add \"TupleSections\"", "Contains TupleSections code action")]
  , codeActionTest "adds TypeApplications pragma" "TypeApplications" [("Add \"TypeApplications\"", "Contains TypeApplications code action")]
  , codeActionTest "after shebang" "AfterShebang" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "append to existing pragmas" "AppendToExisting" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "before doc comments" "BeforeDocComment" [("Add \"NamedFieldPuns\"", "Contains NamedFieldPuns code action")]
  , codeActionTest "before doc comments" "MissingSignatures" [("Disable \"missing-signatures\" warnings", "Contains missing-signatures code action")]
  , codeActionTest "before doc comments" "UnusedImports" [("Disable \"unused-imports\" warnings", "Contains unused-imports code action")]
  , codeActionTest "adds TypeSynonymInstances pragma" "NeedsPragmas" [("Add \"TypeSynonymInstances\"", "Contains TypeSynonymInstances code action"), ("Add \"FlexibleInstances\"", "Contains FlexibleInstances code action")]
  ]

codeActionTest :: String -> FilePath -> [(T.Text, String)] -> TestTree
codeActionTest testComment fp actions =
  goldenWithPragmas testComment fp $ \doc -> do
    _ <- waitForDiagnosticsFrom doc
    cas <- map fromAction <$> getAllCodeActions doc
    mapM_ (\(action, contains) -> go action contains cas) actions
    executeCodeAction $ head cas
    where
      go action contains cas = liftIO $ action `elem` map (^. L.title) cas @? contains

codeActionTests' :: TestTree
codeActionTests' =
  testGroup "additional code actions"
  [ goldenWithPragmas "no duplication" "NamedFieldPuns" $ \doc -> do
      _ <- waitForDiagnosticsFrom doc
      cas <- map fromAction <$> getCodeActions doc (Range (Position 8 9) (Position 8 9))
      liftIO $ length cas == 1 @? "Expected one code action, but got: " <> show cas
      let ca = head cas
      liftIO $ (ca ^. L.title == "Add \"NamedFieldPuns\"") @? "NamedFieldPuns code action"
      executeCodeAction ca
  , goldenWithPragmas "doesn't suggest disabling type errors" "DeferredTypeErrors" $ \doc -> do
      _ <- waitForDiagnosticsFrom doc
      cas <- map fromAction <$> getAllCodeActions doc
      liftIO $ "Disable \"deferred-type-errors\" warnings" `notElem` map (^. L.title) cas @? "Doesn't contain deferred-type-errors code action"
      liftIO $ length cas == 0 @? "Expected no code actions, but got: " <> show cas
  ]

completionTests :: TestTree
completionTests =
  testGroup "completions" [
    completionTest "completes pragmas" "Completion.hs" "" "LANGUAGE" (Just Snippet) (Just "LANGUAGE ${1:extension} #-}") (Just "{-# LANGUAGE #-}") [0, 4, 0, 34, 0, 4]
  , completionTest "completes pragmas with existing closing bracket" "Completion.hs" "" "LANGUAGE" (Just Snippet) (Just "LANGUAGE ${1:extension} #-") (Just "{-# LANGUAGE #-}") [0, 4, 0, 33, 0, 4]
  , completionTest "completes options pragma" "Completion.hs" "OPTIONS" "OPTIONS_GHC" (Just Snippet) (Just "OPTIONS_GHC -${1:option} #-}") (Just "{-# OPTIONS_GHC #-}") [0, 4, 0, 34, 0, 4]
  , completionTest "completes ghc options pragma values" "Completion.hs" "{-# OPTIONS_GHC -Wno-red  #-}\n" "Wno-redundant-constraints" Nothing Nothing Nothing [0, 0, 0, 0, 0, 24]
  , completionTest "completes language extensions" "Completion.hs" "" "OverloadedStrings" Nothing Nothing Nothing [0, 24, 0, 31, 0, 24]
  , completionTest "completes language extensions case insensitive" "Completion.hs" "lAnGuaGe Overloaded" "OverloadedStrings" Nothing Nothing Nothing [0, 4, 0, 34, 0, 24]
  , completionTest "completes the Strict language extension" "Completion.hs" "Str" "Strict" Nothing Nothing Nothing [0, 13, 0, 31, 0, 16]
  , completionTest "completes No- language extensions" "Completion.hs" "NoOverload" "NoOverloadedStrings" Nothing Nothing Nothing [0, 13, 0, 31, 0, 23]
  ]

completionTest :: String -> String -> T.Text -> T.Text -> Maybe InsertTextFormat -> Maybe T.Text -> Maybe T.Text -> [Int] -> TestTree
completionTest testComment fileName te' label textFormat insertText detail [a, b, c, d, x, y] =
  testCase testComment $ runSessionWithServer pragmasPlugin testDataDir $ do
    doc <- openDoc fileName "haskell"
    _ <- waitForDiagnostics
    let te = TextEdit (Range (Position a b) (Position c d)) te'
    _ <- applyEdit doc te
    compls <- getCompletions doc (Position x y)
    let item = head $ filter ((== label) . (^. L.label)) compls
    liftIO $ do
      item ^. L.label @?= label
      item ^. L.kind @?= Just CiKeyword
      item ^. L.insertTextFormat @?= textFormat
      item ^. L.insertText @?= insertText
      item ^. L.detail @?= detail

goldenWithPragmas :: TestName -> FilePath -> (TextDocumentIdentifier -> Session ()) -> TestTree
goldenWithPragmas title path = goldenWithHaskellDoc (runSessionWithServer pragmasPlugin) title testDataDir path "expected" "hs"

testDataDir :: FilePath
testDataDir = "test" </> "testdata"

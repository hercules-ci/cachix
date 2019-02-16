-- Deals with adding private caches to netrc
module Cachix.Client.NetRc
  ( add
  ) where

import qualified Data.ByteString    as BS
import           Data.List            (nubBy)
import           Network.NetRc
import           Protolude
import           System.Directory     ( doesFileExist )
import           Servant.Auth.Client  (getToken)

import qualified Cachix.Api as Api
import           Cachix.Api.Error     (escalateAs)
import           Cachix.Client.Config (Config, authToken)
import           Cachix.Client.Exception (CachixException(NetRcParseError))


-- | Add a list of binary caches to netrc under `filename`.
--   Makes sure there are no duplicate entries (using domain as a key).
--   If file under filename doesn't exist it's created.
add :: Config
    -> [Api.BinaryCache]
    -> FilePath
    -> IO ()
add config binarycaches filename = do
  doesExist <- doesFileExist filename
  netrc <- if doesExist
           then BS.readFile filename >>= parse
           else return $ NetRc [] []
  BS.writeFile filename $ netRcToByteString $ uniqueAppend netrc
  where
    parse :: ByteString -> IO NetRc
    parse contents = escalateAs (NetRcParseError . show) $ parseNetRc filename contents

    -- O(n^2) but who cares?
    uniqueAppend :: NetRc -> NetRc
    uniqueAppend (NetRc hosts macdefs) =
      let
        f :: NetRcHost -> NetRcHost -> Bool
        f x y = nrhName x == nrhName y
      in NetRc (nubBy f (new ++ hosts)) macdefs

    new :: [NetRcHost]
    new = map mkHost $ filter (not . Api.isPublic) binarycaches

    mkHost :: Api.BinaryCache -> NetRcHost
    mkHost bc = NetRcHost
      { nrhName = toS $ Api.uri bc
      , nrhLogin = ""
      , nrhPassword = getToken (authToken config)
      , nrhAccount = ""
      , nrhMacros = []
      }

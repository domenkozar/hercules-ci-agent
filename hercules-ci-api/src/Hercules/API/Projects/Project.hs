{-# LANGUAGE DeriveAnyClass #-}
module Hercules.API.Projects.Project where

import           Prelude
import           Hercules.API.Prelude
import           Hercules.API.Repos.Repo        ( Repo )
import           Hercules.API.SourceHostingSite.SourceHostingSite
                                                ( SourceHostingSite )
import           Hercules.API.Accounts.Account  ( Account )

data Project = Project
  { id :: Id Project
  , ownerId :: Id Account
  , repoId :: Id Repo
  , enabled :: Bool
  , siteSlug :: Name SourceHostingSite
  , slug :: Name Project
  , displayName :: Text
  , imageURL :: Maybe Text
  }
  deriving (Generic, Show, Eq, ToJSON, FromJSON, ToSchema)

import { TSplashDataType } from '../splashPage.types';
import { TStyledSplashMainBlockWrapper } from './styles/SplashMainBlockStyled.styles';

export type TSplashPageMainBlock = TStyledSplashMainBlockWrapper & {
  children: React.ReactNode;
};

export interface ISplashPageWrapper {
  splashData: TSplashDataType;
  loginDone?: boolean;
  connectUserData?: () => Promise<void>;
  setIsSplashPage?: (isSplashPage: boolean) => void;
}

export interface IMainBlockDescription {
  description?: string[] | string | null;
  marginTop: string;
  marginBottom: string;
}

//styled components types
export type TStyledMainBlockTitle = {
  color: string;
  fontSize: string;
  fontWeight: number | string;
  fontFamily: string;
  lineHeight: string;
  textMargin: string;
  textPadding: string;
};

export type TStyledMainBlockDescription = {
  marginTop: string;
  marginBottom: string;
};

export type TStyledMainBlockTextContainer = {
  margin: string;
};

//component's props
export type TMainBlockInfoText = TStyledMainBlockTextContainer & {
  children?: React.ReactNode;
};

export type TMainTitleBlock = TStyledMainBlockTitle & {
  text?: string | string[];
};

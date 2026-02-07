import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
    title: string;
    emoji: string; // 将 Svg 替换为 Emoji 以实现快速视觉更新
    description: ReactNode;
};

const FeatureList: FeatureItem[] = [
    {
        title: 'Precision Picking',
        emoji: '🎯',
        description: (
            <>
                Instantly capture any QR code or Barcode from any part of your screen.
                Just <code>Cmd + Shift + R</code> and pick what you need.
            </>
        ),
    },
    {
        title: 'Privacy by Design',
        emoji: '🛡️',
        description: (
            <>
                Everything happens locally on your Mac. No data collection,
                no cloud processing, and 100% offline security.
            </>
        ),
    },
    {
        title: 'Smart Actions',
        emoji: '⚡',
        description: (
            <>
                Don&apos;t just read data—use it. Auto-connect to WiFi,
                open links in browsers, or compose emails with a single click.
            </>
        ),
    },
];

function Feature({title, emoji, description}: FeatureItem) {
    return (
        <div className={clsx('col col--4')}>
            <div className="text--center">
                {/* 这里使用了一个大的 Emoji 代替默认的 SVG */}
                <span style={{ fontSize: '5rem' }} role="img" aria-label={title}>
          {emoji}
        </span>
            </div>
            <div className="text--center padding-horiz--md">
                <Heading as="h3">{title}</Heading>
                <p>{description}</p>
            </div>
        </div>
    );
}

export default function HomepageFeatures(): ReactNode {
    return (
        <section className={styles.features}>
            <div className="container">
                <div className="row">
                    {FeatureList.map((props, idx) => (
                        <Feature key={idx} {...props} />
                    ))}
                </div>
            </div>
        </section>
    );
}